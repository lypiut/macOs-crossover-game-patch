#!/usr/bin/env python3
"""Replace Mafia RenoDX's live b13 reads with fixed, reviewable literals."""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path


# ShaderInjectData grouped by HLSL constant-buffer register. Perceptual film
# grain is disabled because it needs a frame-varying random seed from the addon.
CONSTANTS = (
    (4.0, 1000.0, 203.0, 203.0),
    (1.0, 1.0, 0.5, 0.0),
    (1.0, 1.0, 1.0, 1.0),
    (1.0, 1.0, 0.0, 0.00001),
    (0.0, 0.0, 1.0, 1.0),
    (1.0, 1.0, 1.0, 1.0),
    (0.0, 1.0, 5.0, 0.0),
    (1.0, 1.0, 0.0, 0.0),
)

INPUTS = (
    "tonemap",
    "loading",
    "videos",
    "videos2",
    "fireworks",
    "dof7",
    "lowhealth",
    "something",
    "proxy-pixel",
)

OPERAND = re.compile(
    r"(?P<neg>-)?(?P<abs>\|?)cb13\[(?P<row>[0-7])\]\."
    r"(?P<swizzle>[xyzw]{1,4})(?P=abs)"
)
COMPONENT = {"x": 0, "y": 1, "z": 2, "w": 3}

# The RenoDX Mafia proxy emits linear BT.709 scRGB. Replace the final scRGB
# store with a BT.709-to-BT.2020 conversion followed by an ST.2084 encode for
# D3DMetal's explicitly signaled HDR10/PQ path. At this point r0.rgb is in nits.
PROXY_SCRGB_STORE = "mul o0:xyz r0.xyzx l(0.0125,0.0125,0.0125,0.0)\n"
PROXY_PQ_STORE = """\
dp3 r1:x l(0.6274039,0.32928303,0.043313067,0.0) r0.xyzx
dp3 r1:y l(0.06909729,0.9195404,0.011362315,0.0) r0.xyzx
dp3 r1:z l(0.01639144,0.088013306,0.89559525,0.0) r0.xyzx
max r1:xyz r1.xyzx l(0.0,0.0,0.0,0.0)
mul r1:xyz r1.xyzx l(0.0001,0.0001,0.0001,0.0)
log r1:xyz r1.xyzx
mul r1:xyz r1.xyzx l(0.1593017578125,0.1593017578125,0.1593017578125,0.0)
exp r1:xyz r1.xyzx
mad r2:xyz r1.xyzx l(18.8515625,18.8515625,18.8515625,0.0) l(0.8359375,0.8359375,0.8359375,0.0)
mad r3:xyz r1.xyzx l(18.6875,18.6875,18.6875,0.0) l(1.0,1.0,1.0,0.0)
div r1:xyz r2.xyzx r3.xyzx
log r1:xyz r1.xyzx
mul r1:xyz r1.xyzx l(78.84375,78.84375,78.84375,0.0)
exp r1:xyz r1.xyzx
min o0:xyz r1.xyzx l(1.0,1.0,1.0,0.0)
"""


def number(value: float) -> str:
    if value == 0:
        return "0.0"
    if value == int(value):
        return f"{int(value)}.0"
    return repr(value)


def replace_operand(match: re.Match[str], proxy_pixel: bool = False) -> str:
    row = CONSTANTS[int(match.group("row"))]
    values = [row[COMPONENT[c]] for c in match.group("swizzle")]
    if (
        proxy_pixel
        and len(values) == 4
        and all(value == values[0] for value in values)
    ):
        repeated = (values[0], values[0], values[0], 0.0)
        literal = "l(" + ",".join(number(value) for value in repeated) + ")"
    elif len(values) == 1 or all(value == values[0] for value in values):
        literal = f"l({number(values[0])})"
    else:
        values += [values[-1]] * (4 - len(values))
        literal = "l(" + ",".join(number(value) for value in values) + ")"
    if match.group("abs"):
        literal = f"|{literal}|"
    if match.group("neg"):
        literal = "-" + literal
    return literal


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--d3dasm", type=Path, required=True)
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    for name in INPUTS:
        source = args.input_dir / f"{name}.dxbc"
        assembly = args.output_dir / f"{name}.d3dasm"
        output = args.output_dir / f"{name}.dxbc"
        subprocess.run(
            [str(args.d3dasm), str(source), "--emit", "d3dasm", "-o", str(assembly)],
            check=True,
        )
        transformed = []
        replacements = 0
        for line in assembly.read_text().splitlines(keepends=True):
            if line.startswith("dcl_constantbuffer cb13["):
                if name != "proxy-pixel":
                    transformed.append(line)
                continue
            line, count = OPERAND.subn(
                lambda match: replace_operand(match, name == "proxy-pixel"), line
            )
            replacements += count
            transformed.append(line)
        if name == "proxy-pixel":
            try:
                store_index = transformed.index(PROXY_SCRGB_STORE)
            except ValueError as error:
                raise RuntimeError("proxy-pixel: scRGB output store not found") from error
            transformed[store_index] = PROXY_PQ_STORE
        assembly.write_text("".join(transformed))
        subprocess.run(
            [str(args.d3dasm), str(assembly), "--assemble", "-o", str(output)],
            check=True,
        )
        verify = subprocess.run(
            [str(args.d3dasm), str(output)], check=True, text=True, capture_output=True
        ).stdout
        live_reads = [
            line
            for line in verify.splitlines()
            if "cb13[" in line and not line.startswith("dcl_constantbuffer cb13[")
        ]
        if live_reads:
            raise RuntimeError(f"{name}: live b13 reads remain: {live_reads[:3]}")
        if replacements == 0 and name != "videos2":
            raise RuntimeError(f"{name}: no b13 operands were replaced")
        print(f"{name}: replacements={replacements} size={output.stat().st_size}")


if __name__ == "__main__":
    main()

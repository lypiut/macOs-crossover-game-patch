# Rebuilding the experimental assets

Normal patch use does not require these build dependencies. This records the
toolchain and transformation used for review and future migration.

## Pinned inputs

- RenoDX revision: `9b212edad4dde9bca2b823b1e045b712b1a8d854`
- Official addon:
  `https://github.com/clshortfuse/renodx/releases/download/nightly-20260922/renodx-mafiade.addon64`
- Addon SHA-256:
  `079f50a6bee9052899e18d77ef5308318e4003fbe4ee9ad1acbfcd442ab695d7`
- `d3dasm` revision: `a292206a15daf0723d945a475c6254413eda8551`
- `cfglib` revision used to build `d3dasm`:
  `d1e683ee5f4cf94a3540b7b40729fdbc752f5eba`
- Compiler: Apple clang `21.0.0` (`clang-2100.3.34.2`)

Obtain dependencies from their official repositories and verify these exact
revisions. Do not pipe downloads into a shell. The runtime patcher never
downloads anything.

## Extract and staticize shaders

The pinned addon contains its compiled shader blobs at these file offsets:

| Output name | Offset | Size |
| --- | ---: | ---: |
| `tonemap.dxbc` | `0x1DA4D0` | `129784` |
| `loading.dxbc` | `0x1FA010` | `1072` |
| `videos.dxbc` | `0x1FA450` | `37868` |
| `videos2.dxbc` | `0x203850` | `424` |
| `fireworks.dxbc` | `0x203B00` | `9304` |
| `dof7.dxbc` | `0x205F70` | `3452` |
| `lowhealth.dxbc` | `0x206D00` | `4508` |
| `something.dxbc` | `0x207EB0` | `4864` |
| `proxy-vertex.dxbc` | `0x2091E0` | `452` |
| `proxy-pixel.dxbc` | `0x2093C0` | `1600` |

Extract each exact range into an input directory, then run:

```bash
python3 src/staticize_shaders.py \
  --d3dasm /path/to/d3dasm \
  --input-dir /path/to/extracted-dxbc \
  --output-dir /path/to/static-dxbc
```

The tool disassembles losslessly, replaces every runtime `b13` read with a
literal from the documented profile, and changes the proxy's final linear
scRGB store to BT.2020 plus ST.2084 PQ. It then reassembles, disassembles again,
and fails if a live read remains. The vertex shader is copied unchanged. The
exact expected output hashes are recorded in `patch-hdr.sh`.

## Build the PE payload

`src/mafiade_hdr_payload.c` is freestanding C compiled for x86-64 with the
Microsoft ABI:

```bash
clang -arch x86_64 -O2 -fno-stack-protector \
  -fno-asynchronous-unwind-tables -fno-unwind-tables -fno-exceptions \
  -ffreestanding -c src/mafiade_hdr_payload.c -o payload.o
```

The two proxy DXBC files are embedded through `src/mafiade_hdr_shaders.s` using
`.incbin`, linked with `payload.o` as a temporary Mach-O dylib, and the
contiguous range from `hdr_create_backbuffer_proxy` through the end of the
proxy pixel shader is extracted. The final section adds a 16-byte-aligned
cleanup trampoline and zero padding to `0x1000` bytes. Review these required
symbol offsets before packaging:

| Symbol | Section-relative offset |
| --- | ---: |
| `hdr_create_backbuffer_proxy` | `0x000` |
| `hdr_release_backbuffer_proxy` | `0x2B0` |
| `hdr_present` | `0x2F0` |
| proxy vertex shader | `0x550` |
| proxy pixel shader | `0x720` |
| cleanup trampoline | `0xF60` |

The packaged section SHA-256 must be
`7f34283b5f0b93a3226a4f8fec81c9f81da18312d9df8bc72fc4e10658624cfa`.
Do not update that value or the final output allowlists without re-reviewing
the disassembly and rerunning all fixture and in-game checks.

## Package

Package the section plus eight static game shaders—never the original game
files—into `mafiade-hdr-assets.tar.gz`, base64-encode it, and update the archive
and member hashes only after review. The current decoded archive SHA-256 is
`93546dad0c22f65811e156baeb5a6b1523487b54ce17e44ee0d25186f73f1fdd`.

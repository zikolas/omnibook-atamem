#!/usr/bin/env python3
"""obpatch.py - patch the OBCBIOS module in an HP OmniBook 425 ROM card image
so PC Card ATA / CompactFlash cards run in memory mode (options 1-5), and
optionally ROM DOS's OBMGM check (option 7).

Usage:
    python3 obpatch.py [options] ROM-IN.IMG ROM-OUT.IMG
    python3 obpatch.py --check ROM.IMG
    python3 obpatch.py --list
    python3 obpatch.py OBMGM.COM OBMGM-OUT.COM   (nopopup, see --list)

Options (default: the five OBCBIOS patches):
    --only NAMES      apply exactly these patches (comma separated)
    --without NAMES   apply the default patches except these
    noobmgm (ROM DOS) is not in the default; add it with --only, e.g.
    --only anycard,sectors63,sizecap,nopowerdown,nosetfeatures,noobmgm

The input is a dump of the 425's ROM card (for example made with LINGO).
The patcher finds OBCBIOS through the card's own directory, checks it is the
exact stock build, applies the chosen patches to a copy and checks the
result against the known CRC for that combination. It never changes the
input file and contains no HP code.

Experimental, limited testing: keep your original ROM card and dump.
"""

import struct
import sys
import zlib

DIR_TOP = 0x7F7FF0              # ROM card directory, read downward
DIR_FLOOR = 0x7F4000
MOD_NAME = b"OBCBIOS\0"
MOD_LEN = 0x3A2B

SIZE_CAP_A = bytes.fromhex(
    "fcbe000426ad26ad9226ad26ad88c726ad26ad26ad88c3b9f90026f3ad89d8"
    "eb1080fa407205b23f83c8ffc39090909090")
SIZE_CAP_B = bytes.fromhex("f6e4f7e2e89ffd0fa4c209c1e0099090")

# name, help, [(module offset, expected old bytes or None, new bytes)]
OPTIONS = [
    ("anycard",
     "memory mode for every card maker, not only SanDisk (MANFID 0045). "
     "Needed for any non-SanDisk card: as C: it otherwise runs in I/O mode "
     "(8-bit cards in the user slots lose their odd ports), and in a user "
     "slot it is otherwise 'Unrecognized'.",
     [(0x2E57, b"\x74", b"\xeb"), (0x2E61, b"\x74", b"\xeb")]),
    ("sectors63",
     "fix HP's IDENTIFY check, which tests sectors/track instead of the "
     "error bit. Needed for cards with 63 sectors per track (most CF cards "
     "of 64MB and up, SanDisk included); they otherwise get size 0. "
     "No downside.",
     [(0x2D58, b"\x01", b"\x00")]),
    ("sizecap",
     "cap the recorded card size at just under 2GB. HP's 32-bit size "
     "wraps on cards of 4GB and up and accesses beyond the wrapped size "
     "fail. No downside: DOS uses at most 2GB per partition.",
     [(0x2D1F, None, SIZE_CAP_A), (0x2F9A, None, SIZE_CAP_B)]),
    ("nopowerdown",
     "do not put cards into power-down after 5 seconds idle. Needed for "
     "cards that stay busy after HP wakes them (Transcend TS1GCF133). "
     "Costs battery: cards draw more while idle.",
     [(0x2BF4, b"\x04", b"\x00")]),
    ("nosetfeatures",
     "skip the two SanDisk vendor SET FEATURES commands (69h, 97h) sent "
     "when a card comes up. Needed for the IBM Microdrive, which aborts "
     "every command after them. Their effect on SanDisk cards (probably "
     "power saving) is not known.",
     [(0x2DBA, b"\x80\x7c", b"\xeb\x1f")]),
]
NAMES = [o[0] for o in OPTIONS] + ["noobmgm"]
OBC_MASK = (1 << len(OPTIONS)) - 1          # the OBCBIOS parts (bits 0-4)
NOOBMGM = 1 << len(OPTIONS)                 # option 7 (bit 5)
DEFAULT_MASK = OBC_MASK

# Option 7, noobmgm: ROM DOS (the DOSHI module, an SZDD-compressed stream)
# checks after CONFIG.SYS that OBMGM.COM is resident and otherwise reboots
# from drive D.  The check routine's first byte is stored as a literal in the
# compressed stream, so one byte turns it into a RET.
DOSHI_NAME = b"DOSHI\0\0\0"
DOSHI_LEN = 0x7000
DOSHI_CRC_STOCK = 0x0C4872EF
DOSHI_CRC_PATCHED = 0xF89B2143
DOSHI_SITE = (0x1BAF, b"\xb5", b"\xc3")

# Module CRC-32 for every combination; index bit n = OPTIONS[n] applied.
# Index 0 is the stock module (US 1.1S ABA and UK 1.1S ABB cards).
CRC_TABLE = [
    0x590D344E, 0x3A6BC7A4, 0x997DA9B2, 0xFA1B5A58,
    0xA4B58F0F, 0xC7D37CE5, 0x64C512F3, 0x07A3E119,
    0xCFE72EA9, 0xAC81DD43, 0x0F97B355, 0x6CF140BF,
    0x325F95E8, 0x51396602, 0xF22F0814, 0x9149FBFE,
    0x6D905B1D, 0x0EF6A8F7, 0xADE0C6E1, 0xCE86350B,
    0x9028E05C, 0xF34E13B6, 0x50587DA0, 0x333E8E4A,
    0xFB7A41FA, 0x981CB210, 0x3B0ADC06, 0x586C2FEC,
    0x06C2FABB, 0x65A40951, 0xC6B26747, 0xA5D494AD,
]


# OBMGM.COM 1.03 (the OmniBook message manager, loaded by CONFIG.SYS):
# option 6, nopopup, sends the two "Unrecognized Plug-in Card" cases of its
# message selector (jump table at file offset 4AE5h) to the selector's exit.
OBMGM_LEN = 22341
OBMGM_CRC_STOCK = 0x8AAE549B
OBMGM_CRC_PATCHED = 0x2F9D6F3B
OBMGM_SITE = (0x4AE5, b"\xf8\x4b\xfd\x4b", b"\x1d\x4c\x1d\x4c")


def patch_obmgm(data, check_only, dst, src):
    c = crc(data)
    if c == OBMGM_CRC_PATCHED:
        print("OBMGM.COM 1.03 already has nopopup (CRC %08X). Nothing to do."
              % c)
        return 0
    if c != OBMGM_CRC_STOCK:
        print("OBMGM.COM CRC %08X is not the known 1.03 build. Refusing." % c)
        return 1
    print("OBMGM.COM 1.03, stock (CRC %08X)" % c)
    if check_only:
        return 0
    if dst == src:
        print("output must be a different file from the input")
        return 2
    off, old, new = OBMGM_SITE
    out = bytearray(data)
    if out[off:off + len(old)] != old:
        print("unexpected bytes at %04Xh, refusing" % off)
        return 1
    out[off:off + len(new)] = new
    if crc(out) != OBMGM_CRC_PATCHED:
        print("internal error: patched CRC %08X" % crc(out))
        return 1
    with open(dst, "wb") as f:
        f.write(out)
    print("applied: nopopup")
    print("wrote %s: %d bytes, CRC-32 %08X" % (dst, len(out), crc(out)))
    print("Copy it over C:\\OBMGM.COM on the 425 (keep the original).")
    return 0


def crc(data):
    return zlib.crc32(data) & 0xFFFFFFFF


def mask_names(mask):
    return ", ".join(n for i, n in enumerate(NAMES) if mask >> i & 1) or "none"


def find_module(img, name=MOD_NAME):
    off = DIR_TOP
    while off >= DIR_FLOOR and off + 16 <= len(img):
        ent = img[off:off + 16]
        if ent[0] == 0:
            break
        if ent[:8] == name:
            start, = struct.unpack_from("<I", ent, 8)
            length, = struct.unpack_from("<H", ent, 12)
            return start, length
        off -= 16
    return None


def parse_names(text):
    names = [n.strip().lower() for n in text.split(",") if n.strip()]
    bad = [n for n in names if n not in NAMES]
    if bad:
        raise SystemExit("unknown patch name(s): %s (use --list)"
                         % ", ".join(bad))
    return sum(1 << NAMES.index(n) for n in names)


def list_options():
    for i, (name, text, _) in enumerate(OPTIONS):
        print("%d. %s" % (i + 1, name))
        words, line = text.split(), "   "
        for w in words:
            if len(line) + len(w) + 1 > 78:
                print(line)
                line = "   "
            line += " " + w
        print(line)
    print("6. nopopup  (applies to OBMGM.COM, not to the ROM image)")
    print("    stop OBMGM showing the 'Unrecognized Plug-in Card' popup when a")
    print("    card it does not know is inserted. Other OBMGM messages stay.")
    print("    Run obpatch.py on C:\\OBMGM.COM to apply it.")
    print("7. noobmgm  (ROM DOS, not part of the default)")
    print("    ROM DOS reboots from drive D when OBMGM.COM is not resident")
    print("    after CONFIG.SYS. This removes that check, so CONFIG.SYS can")
    print("    leave OBMGM out (about 20K more memory) without other tools.")
    print("\nDefault for a ROM image: options 1-5 (the combination tested on")
    print("hardware).")


def main(argv):
    args, mask, check_only = [], DEFAULT_MASK, False
    it = iter(argv)
    for a in it:
        if a == "--list":
            list_options()
            return 0
        elif a == "--check":
            check_only = True
        elif a == "--only":
            mask = parse_names(next(it, ""))
        elif a == "--without":
            mask = DEFAULT_MASK & ~parse_names(next(it, ""))
        elif a.startswith("--"):
            print("unknown option %s" % a)
            return 2
        else:
            args.append(a)
    if (check_only and len(args) != 1) or (not check_only and len(args) != 2):
        print(__doc__.strip().split("\n\n")[1])
        print()
        print(__doc__.strip().split("\n\n")[2])
        print()
        print(__doc__.strip().split("\n\n")[-1])
        return 2

    src = args[0]
    with open(src, "rb") as f:
        img = bytearray(f.read())
    if len(img) == OBMGM_LEN:
        return patch_obmgm(bytes(img), check_only,
                           args[1] if len(args) > 1 else None, src)
    print("image %s: %d bytes, CRC-32 %08X" % (src, len(img), crc(img)))
    found = find_module(img)
    if not found:
        print("no OBCBIOS entry in the ROM card directory at %06Xh: "
              "not a 425 ROM card image" % DIR_TOP)
        return 1
    start, length = found
    print("OBCBIOS at card %06Xh, %04Xh bytes" % (start, length))
    if length != MOD_LEN or start + length > len(img):
        print("unexpected OBCBIOS length: not a supported build "
              "(OmniBook 300 and 430 cards are not supported)")
        return 1
    mod = bytes(img[start:start + length])
    mcrc = crc(mod)
    if mcrc not in CRC_TABLE:
        print("OBCBIOS CRC %08X is not a known 425 build. Refusing." % mcrc)
        return 1
    have = CRC_TABLE.index(mcrc)
    if have:
        print("OBCBIOS is already patched (CRC %08X): %s"
              % (mcrc, mask_names(have)))
    else:
        print("OBCBIOS is the stock 425 build (CRC %08X)" % mcrc)

    dfound = find_module(img, DOSHI_NAME)
    dcrc = None
    if dfound and dfound[1] == DOSHI_LEN and \
            dfound[0] + DOSHI_LEN <= len(img):
        dstart = dfound[0]
        dcrc = crc(bytes(img[dstart:dstart + DOSHI_LEN]))
    if dcrc == DOSHI_CRC_PATCHED:
        print("ROM DOS already has noobmgm (DOSHI CRC %08X)" % dcrc)
    elif dcrc == DOSHI_CRC_STOCK:
        print("ROM DOS is the stock 425 build (DOSHI CRC %08X)" % dcrc)
    else:
        print("ROM DOS (DOSHI) is not a known build: noobmgm unavailable")
    if check_only:
        return 0

    obc = mask & OBC_MASK
    want_doshi = bool(mask & NOOBMGM)
    if mask == 0:
        print("no patches selected, nothing written")
        return 2
    if obc and have and obc != have:
        print("OBCBIOS already has a different set of patches.")
        print("To apply a different set, start from the original dump.")
        return 1
    if want_doshi and dcrc not in (DOSHI_CRC_STOCK, DOSHI_CRC_PATCHED):
        print("noobmgm needs the stock 425 ROM DOS. Refusing.")
        return 1
    do_obc = obc and not have
    do_doshi = want_doshi and dcrc == DOSHI_CRC_STOCK
    if not do_obc and not do_doshi:
        print("the image already has the selected patches, nothing written")
        return 0
    dst = args[1]
    if dst == src:
        print("output must be a different file from the input")
        return 2

    if do_obc:
        out = bytearray(mod)
        for i, (_, _, sites) in enumerate(OPTIONS):
            if not obc >> i & 1:
                continue
            for moff, old, new in sites:
                if old is not None and out[moff:moff + len(old)] != old:
                    print("unexpected bytes at module %04Xh, refusing" % moff)
                    return 1
                out[moff:moff + len(new)] = new
        if crc(out) != CRC_TABLE[obc]:
            print("internal error: patched CRC %08X, expected %08X"
                  % (crc(out), CRC_TABLE[obc]))
            return 1
        img[start:start + length] = out
        print("OBCBIOS: applied %s, CRC %08X" % (mask_names(obc), crc(out)))
    if do_doshi:
        doff, old, new = DOSHI_SITE
        if img[dstart + doff:dstart + doff + len(old)] != old:
            print("unexpected bytes in ROM DOS, refusing")
            return 1
        img[dstart + doff:dstart + doff + len(new)] = new
        if crc(bytes(img[dstart:dstart + DOSHI_LEN])) != DOSHI_CRC_PATCHED:
            print("internal error: patched DOSHI CRC mismatch")
            return 1
        print("ROM DOS: applied noobmgm, DOSHI CRC %08X" % DOSHI_CRC_PATCHED)
    with open(dst, "wb") as f:
        f.write(img)
    print("wrote %s: %d bytes, CRC-32 %08X" % (dst, len(img), crc(img)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

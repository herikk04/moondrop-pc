"""Emula libnative-peq.so (ARM64, Airoha) no PC para obter os coeficientes PEQ
exatos que o app oficial calcula. Uso interno: gabarito para validar a versao Dart."""
import math
import struct
import sys

from elftools.elf.elffile import ELFFile
from unicorn import (Uc, UC_ARCH_ARM64, UC_MODE_ARM, UC_HOOK_CODE, UC_HOOK_MEM_UNMAPPED)
from unicorn.arm64_const import *

LIB = r"H:\moondrop-port\xapk_extraido\_arm64\lib\arm64-v8a\libnative-peq.so"
BASE = 0x40000000
STUB = 0x10000000
RET_ADDR = 0x10100000
HEAP = 0x20000000
HEAP_SIZE = 0x4000000
STACK = 0x70000000
STACK_SIZE = 0x200000
TLS = 0x71000000
PAGE = 0x1000


def up(x, a=PAGE):
    return (x + a - 1) & ~(a - 1)


class PeqEmu:
    def __init__(self):
        data = open(LIB, "rb").read()
        self.elf = ELFFile(open(LIB, "rb"))
        self.mu = Uc(UC_ARCH_ARM64, UC_MODE_ARM)
        mu = self.mu
        # segmentos
        for seg in self.elf.iter_segments():
            if seg["p_type"] != "PT_LOAD":
                continue
            start = BASE + (seg["p_vaddr"] & ~(PAGE - 1))
            end = BASE + up(seg["p_vaddr"] + seg["p_memsz"])
            mu.mem_map(start, end - start)
            mu.mem_write(BASE + seg["p_vaddr"], data[seg["p_offset"]: seg["p_offset"] + seg["p_filesz"]])
        # stubs, retorno, heap, pilha, TLS
        mu.mem_map(STUB, 0x200000)
        mu.mem_map(HEAP, HEAP_SIZE)
        mu.mem_map(STACK, STACK_SIZE)
        mu.mem_map(TLS, PAGE)
        mu.mem_write(RET_ADDR, struct.pack("<I", 0xD65F03C0))  # ret
        self.heap_ptr = HEAP + 0x10000
        self.imports = {}
        self._relocate()
        mu.reg_write(UC_ARM64_REG_TPIDR_EL0, TLS)
        mu.mem_write(TLS + 0x28, struct.pack("<Q", 0x1122334455667788))
        mu.reg_write(UC_ARM64_REG_CPACR_EL1, 0x300000)  # habilita FP/NEON
        mu.hook_add(UC_HOOK_CODE, self._code_hook, begin=STUB, end=STUB + 0x100000)
        self.sf = self._alloc(0x400)  # __sF (FILE[3])
        self.errno = self._alloc(8)
        self.fs_addr = {}

    # ---------------------------------------------------------------- util
    def _alloc(self, n):
        p = (self.heap_ptr + 15) & ~15
        self.heap_ptr = p + n
        if self.heap_ptr > HEAP + HEAP_SIZE:
            raise MemoryError("heap emulado esgotado")
        return p

    def _relocate(self):
        mu = self.mu
        dynsym = self.elf.get_section_by_name(".dynsym")
        syms = list(dynsym.iter_symbols())
        nstub = 0
        for secname in (".rela.dyn", ".rela.plt"):
            sec = self.elf.get_section_by_name(secname)
            for r in sec.iter_relocations():
                off = BASE + r["r_offset"]
                typ = r["r_info_type"]
                add = r["r_addend"]
                if typ == 1027:  # RELATIVE
                    mu.mem_write(off, struct.pack("<Q", BASE + add))
                    continue
                s = syms[r["r_info_sym"]]
                if s["st_shndx"] != "SHN_UNDEF":
                    val = BASE + s["st_value"] + add
                else:
                    name = s.name
                    if name not in self.imports:
                        self.imports[name] = STUB + 8 * (len(self.imports) + 1)
                        mu.mem_write(self.imports[name], struct.pack("<I", 0xD65F03C0))
                    val = self.imports[name] + add
                if typ in (1025, 1026, 257):
                    mu.mem_write(off, struct.pack("<Q", val))
        self.stub_names = {v: k for k, v in self.imports.items()}

    def sym(self, name):
        ds = self.elf.get_section_by_name(".dynsym")
        for s in ds.iter_symbols():
            if s.name == name and s["st_shndx"] != "SHN_UNDEF":
                return BASE + s["st_value"]
        raise KeyError(name)

    # --------------------------------------------------------- stubs (libc/libm)
    def _fp(self, reg):
        return struct.unpack("<d", struct.pack("<Q", self.mu.reg_read(reg) & 0xFFFFFFFFFFFFFFFF))[0]

    def _setfp(self, reg, v):
        self.mu.reg_write(reg, struct.unpack("<Q", struct.pack("<d", v))[0])

    def _code_hook(self, mu, addr, size, ud):
        name = self.stub_names.get(addr)
        if name is None:
            return
        x = lambda i: mu.reg_read(UC_ARM64_REG_X0 + i)
        d0 = lambda: self._fp(UC_ARM64_REG_D0)
        d1 = lambda: self._fp(UC_ARM64_REG_D1)
        ret = 0
        if name == "malloc":
            ret = self._alloc(x(0))
        elif name == "posix_memalign":
            p = (self.heap_ptr + x(1) - 1) & ~(x(1) - 1)
            self.heap_ptr = p + x(2)
            mu.mem_write(x(0), struct.pack("<Q", p))
        elif name == "realloc":
            ret = self._alloc(x(1))
            if x(0):
                try:
                    mu.mem_write(ret, bytes(mu.mem_read(x(0), x(1))))
                except Exception:
                    pass
        elif name == "memset":
            mu.mem_write(x(0), bytes([x(1) & 0xFF]) * x(2))
            ret = x(0)
        elif name in ("memcpy", "memmove", "__memcpy_chk"):
            mu.mem_write(x(0), bytes(mu.mem_read(x(1), x(2))))
            ret = x(0)
        elif name == "pow":
            self._setfp(UC_ARM64_REG_D0, math.pow(d0(), d1()))
        elif name == "exp":
            self._setfp(UC_ARM64_REG_D0, math.exp(d0()))
        elif name == "log":
            self._setfp(UC_ARM64_REG_D0, math.log(d0()))
        elif name == "log10":
            self._setfp(UC_ARM64_REG_D0, math.log10(d0()))
        elif name == "hypot":
            self._setfp(UC_ARM64_REG_D0, math.hypot(d0(), d1()))
        elif name == "atan2":
            self._setfp(UC_ARM64_REG_D0, math.atan2(d0(), d1()))
        elif name == "acosh":
            self._setfp(UC_ARM64_REG_D0, math.acosh(d0()))
        elif name == "cosh":
            self._setfp(UC_ARM64_REG_D0, math.cosh(d0()))
        elif name == "sincos":
            v = d0()
            mu.mem_write(x(0), struct.pack("<d", math.sin(v)))
            mu.mem_write(x(1), struct.pack("<d", math.cos(v)))
        elif name == "__stack_chk_fail" or name == "abort":
            raise RuntimeError(name)
        elif name == "__errno":
            ret = self.errno
        elif name == "__sF":
            ret = 0
        elif name == "qsort":
            self._qsort(x(0), x(1), x(2), x(3))
        # demais (log, fopen, pthread...) retornam 0
        mu.reg_write(UC_ARM64_REG_X0, ret)

    # qsort do Bionic (FreeBSD), com os comparadores compare1/compare2 da propria lib.
    def _qsort(self, base, n, es, cmp_addr):
        mem = self.mu.mem_read
        if cmp_addr == BASE + 0x1E6C8:  # compare1: chave double em +8, decrescente
            def cmp(a, b):
                da = struct.unpack("<d", a[8:16])[0]
                db = struct.unpack("<d", b[8:16])[0]
                r = -(1 if db < da else 0)
                return 1 if da < db else r
        elif cmp_addr == BASE + 0x1E6E0:  # compare2: int32 crescente
            def cmp(a, b):
                return struct.unpack("<i", a[:4])[0] - struct.unpack("<i", b[:4])[0]
        else:
            raise RuntimeError("comparador de qsort desconhecido: %x" % cmp_addr)
        arr = [bytes(mem(base + i * es, es)) for i in range(n)]

        def swap(i, j):
            arr[i], arr[j] = arr[j], arr[i]

        def vecswap(i, j, cnt):
            for k in range(cnt):
                swap(i + k, j + k)

        def med3(a, b, c):
            if cmp(arr[a], arr[b]) < 0:
                return b if cmp(arr[b], arr[c]) < 0 else (c if cmp(arr[a], arr[c]) < 0 else a)
            return b if cmp(arr[b], arr[c]) > 0 else (c if cmp(arr[a], arr[c]) > 0 else a)

        def ins(a, n_):
            for pm in range(a + 1, a + n_):
                pl = pm
                while pl > a and cmp(arr[pl - 1], arr[pl]) > 0:
                    swap(pl, pl - 1)
                    pl -= 1

        def sort(a, n_):
            while True:
                swap_cnt = 0
                if n_ < 7:
                    ins(a, n_)
                    return
                pm = a + n_ // 2
                if n_ > 7:
                    pl = a
                    pn = a + n_ - 1
                    if n_ > 40:
                        d = n_ // 8
                        pl = med3(pl, pl + d, pl + 2 * d)
                        pm = med3(pm - d, pm, pm + d)
                        pn = med3(pn - 2 * d, pn - d, pn)
                    pm = med3(pl, pm, pn)
                swap(a, pm)
                pa = pb = a + 1
                pc = pd = a + n_ - 1
                while True:
                    while pb <= pc:
                        r = cmp(arr[pb], arr[a])
                        if r > 0:
                            break
                        if r == 0:
                            swap_cnt = 1
                            swap(pa, pb)
                            pa += 1
                        pb += 1
                    while pb <= pc:
                        r = cmp(arr[pc], arr[a])
                        if r < 0:
                            break
                        if r == 0:
                            swap_cnt = 1
                            swap(pc, pd)
                            pd -= 1
                        pc -= 1
                    if pb > pc:
                        break
                    swap(pb, pc)
                    swap_cnt = 1
                    pb += 1
                    pc -= 1
                if swap_cnt == 0:
                    ins(a, n_)
                    return
                pn = a + n_
                r = min(pa - a, pb - pa)
                vecswap(a, pb - r, r)
                r = min(pd - pc, pn - pd - 1)
                vecswap(pb, pn - r, r)
                r = pb - pa
                if r > 1:
                    sort(a, r)
                r = pd - pc
                if r > 1:
                    a = pn - r
                    n_ = r
                    continue
                return

        sort(0, n)
        self.mu.mem_write(base, b"".join(arr))

    # ----------------------------------------------------------------- chamadas
    def call(self, addr, ints=(), floats=()):
        mu = self.mu
        for i, v in enumerate(ints):
            mu.reg_write(UC_ARM64_REG_X0 + i, v & 0xFFFFFFFFFFFFFFFF)
        for i, v in enumerate(floats):
            self._setfp(UC_ARM64_REG_D0 + i, float(v))
        mu.reg_write(UC_ARM64_REG_SP, STACK + STACK_SIZE - 0x1000)
        mu.reg_write(UC_ARM64_REG_LR, RET_ADDR)
        mu.emu_start(addr, RET_ADDR, timeout=60_000_000)
        return mu.reg_read(UC_ARM64_REG_X0)

    def compute(self, fs, bands, rescale_db=0.0, thread=0):
        """bands: lista de (freq_hz, gain_db, q). Devolve (count, [shorts])."""
        n = len(bands)
        self.call(self.sym("setParam"), ints=(thread, n, 0, 0, 0), floats=(fs,))
        for i, (f, g, q) in enumerate(bands):
            self.call(self.sym("set_peq_point"), ints=(thread, i), floats=(f, g, q))
        self.call(self.sym("generate_cofe"), ints=(thread,))
        self.call(self.sym("change_rescale_cofe"), ints=(thread,), floats=(rescale_db,))
        self.call(self.sym("get_cofe_count"), ints=(thread,))
        gp = struct.unpack("<Q", bytes(self.mu.mem_read(self.sym("g_param") if False else self._gparam(), 8)))[0]
        gp_t = struct.unpack("<Q", bytes(self.mu.mem_read(self._gparam() + 8 * thread, 8)))[0]
        count = struct.unpack("<H", bytes(self.mu.mem_read(gp_t + 0x183E0, 2)))[0]
        raw = bytes(self.mu.mem_read(gp_t + 0x183E2, count * 2))
        shorts = list(struct.unpack("<%dh" % count, raw))
        self.call(self.sym("destroy"), ints=(thread,))
        return count, shorts

    def _gparam(self):
        # g_param e uma variavel global; achamos pelo simbolo se exportado, senao por heuristica
        ds = self.elf.get_section_by_name(".symtab") or self.elf.get_section_by_name(".dynsym")
        for s in ds.iter_symbols():
            if s.name == "g_param" and s["st_shndx"] != "SHN_UNDEF":
                return BASE + s["st_value"]
        raise KeyError("g_param")


if __name__ == "__main__":
    emu = PeqEmu()
    fs = float(sys.argv[1]) if len(sys.argv) > 1 else 48000.0
    bands = [(20, 0.0, 0.707), (200, 3.0, 1.0), (2000, -2.0, 1.4), (12000, 1.5, 0.707), (20000, 0.0, 0.707)]
    count, shorts = emu.compute(fs, bands)
    print("fs", fs, "count", count)
    print([f"{(s & 0xFFFF):04X}" for s in shorts])

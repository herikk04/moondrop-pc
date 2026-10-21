import asyncio, struct, sys
from bleak import BleakClient
ADDR="AA:BB:CC:DD:EE:01"
CMD="00001101-d102-11e1-9b23-00025b00a5a5"; RSP="00001102-d102-11e1-9b23-00025b00a5a5"
def pkt(f,t,c,p=b""): return struct.pack(">HH",0x001D,(f<<9)|(t<<7)|c)+p
def dec(b):
    v,c=struct.unpack(">HH",b[:4]); return f"feature={c>>9} type={(c>>7)&3} cmd={c&0x7f} payload={b[4:].hex()}"
async def main():
    async with BleakClient(ADDR,timeout=25) as c:
        await c.start_notify(RSP, lambda s,d: print("  <-",dec(bytes(d)),flush=True))
        for name,cmd in [("AUDIO_CURATION GET_MODE (cmd 3)",3),("AUDIO_CURATION GET_SWITCH_CONF (cmd 0x29)",0x29)]:
            print("->",name,flush=True)
            await c.write_gatt_char(CMD,pkt(8,0,cmd),response=True)
            await asyncio.sleep(2)
asyncio.run(main())

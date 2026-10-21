import asyncio, struct
from bleak import BleakClient
ADDR="25:09:23:B6:31:8E"
CMD="00001101-d102-11e1-9b23-00025b00a5a5"; RSP="00001102-d102-11e1-9b23-00025b00a5a5"
def pkt(f,t,c,p=b""): return struct.pack(">HH",0x001D,(f<<9)|(t<<7)|c)+p
def dec(b):
    v,c=struct.unpack(">HH",b[:4]); return f"feature={c>>9} type={(c>>7)&3} cmd={c&0x7f} payload={b[4:].hex()}"
async def main():
    async with BleakClient(ADDR,timeout=25) as c:
        await c.start_notify(RSP, lambda s,d: print("  <-",dec(bytes(d)),flush=True))
        for name,f,cmd in [("ANC_V3 GET_MODE",33,3),("ANC_V2 GET_MODE",32,3),("ANC(2) cmd3",2,3),("BATTERY cmd0",13,0),("BATTERY cmd1",13,1),("CODEC_TYPE cmd0",16,0),("DAC_GAIN cmd0",15,0),("MUSIC_PROC cmd0",5,0),("MUSIC_PROC cmd1",5,1)]:
            print("->",name,flush=True)
            await c.write_gatt_char(CMD,pkt(f,0,cmd),response=True)
            await asyncio.sleep(1.5)
asyncio.run(main())

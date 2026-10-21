import asyncio, struct
from bleak import BleakClient
ADDR="25:09:23:B6:31:8E"
CMD ="00001101-d102-11e1-9b23-00025b00a5a5"
RSP ="00001102-d102-11e1-9b23-00025b00a5a5"
DAT ="00001103-d102-11e1-9b23-00025b00a5a5"
VENDOR=0x001D
def pkt(feature, ptype, cid, payload=b""):
    return struct.pack(">HH", VENDOR, (feature<<9)|(ptype<<7)|cid) + payload
def dec(b):
    if len(b)<4: return b.hex()
    v,c=struct.unpack(">HH",b[:4]); return f"vendor=0x{v:04x} feature={c>>9} type={(c>>7)&3} cmd={c&0x7f} payload={b[4:].hex()}"
async def main():
    rx=[]
    async with BleakClient(ADDR, timeout=25) as c:
        def h(tag):
            return lambda _,d: (rx.append((tag,bytes(d))), print(f"<- {tag}: {dec(bytes(d))}"))
        await c.start_notify(RSP, h("1102"))
        await c.start_notify(DAT, h("1103"))
        for name,p in [("GET_API_VERSION",pkt(0,0,0)),("GET_SUPPORTED_FEATURES",pkt(0,0,1))]:
            print("->",name,p.hex())
            await c.write_gatt_char(CMD,p,response=True)
            await asyncio.sleep(2)
asyncio.run(main())

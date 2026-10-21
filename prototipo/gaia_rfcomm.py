import asyncio, struct, sys
from winrt.windows.devices.bluetooth import BluetoothDevice, BluetoothCacheMode
from winrt.windows.devices.bluetooth.rfcomm import RfcommServiceId
from winrt.windows.networking.sockets import StreamSocket
from winrt.windows.storage.streams import DataWriter, DataReader, InputStreamOptions
import uuid
ADDR=int("25:09:23:B6:31:DB".replace(":",""),16)
GAIA=uuid.UUID("00001101-0000-1000-8000-00805F9B34FB")
def gaia(f,t,c,p=b"",checksum=False):
    body=struct.pack(">HH",0x001D,(f<<9)|(t<<7)|c)+p
    fr=bytes([0xFF,0x03,1 if checksum else 0,len(p)])+body
    if checksum:
        x=0
        for b in fr: x^=b
        fr+=bytes([x])
    return fr
async def main():
    dev=await BluetoothDevice.from_bluetooth_address_async(ADDR)
    print("device:",dev.name,"status",dev.connection_status)
    res=await dev.get_rfcomm_services_with_cache_mode_async(BluetoothCacheMode.UNCACHED)
    print("rfcomm err:",res.error)
    for s in res.services:
        print(" svc",s.service_id.uuid,"host",s.connection_host_name.canonical_name,"port",s.connection_service_name)
    sel=[s for s in res.services if uuid.UUID(str(s.service_id.uuid))==GAIA]
    if not sel: print("GAIA RFCOMM service not found"); return
    s=sel[0]
    sock=StreamSocket()
    await sock.connect_async(s.connection_host_name, s.connection_service_name)
    print("connected RFCOMM")
    w=DataWriter(sock.output_stream); r=DataReader(sock.input_stream); r.input_stream_options=InputStreamOptions.PARTIAL
    inbox=bytearray()
    async def reader():
        try:
            while True:
                n=await r.load_async(256)
                if n==0: break
                buf=bytearray(n); r.read_bytes(buf); inbox.extend(buf)
        except Exception as e: print("reader fim:",type(e).__name__,flush=True)
    rt=asyncio.ensure_future(reader())
    def parse(b):
        res=[]
        while len(b)>=8 and b[0]==0xFF:
            L=b[3]; flags=b[2]; tot=4+4+L+(1 if flags&1 else 0)
            v,c=struct.unpack(">HH",b[4:8]); res.append(f"[v{b[1]} len={L} feature={c>>9} type={(c>>7)&3} cmd={c&0x7f} payload={b[8:8+L].hex()}]"); b=b[tot:]
        return " ".join(res) or "(vazio)"
    async def txrx(name,frame):
        inbox.clear()
        print("->",name,frame.hex(),flush=True)
        w.write_bytes(frame); await w.store_async()
        await asyncio.sleep(2.0)
        raw=bytes(inbox); print("  <-",parse(raw),"|",raw.hex(),flush=True)
    await txrx("API_VERSION",gaia(0,0,0))
    await txrx("SUPPORTED_FEATURES",gaia(0,0,1))
    for name,fe in [("ANC_V3 GET_MODE",33),("ANC_V2 GET_MODE",32),("ANC GET (2)",2)]:
        await txrx(name,gaia(fe,0,3))
    sock.close()
asyncio.run(main())

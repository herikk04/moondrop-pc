import asyncio, time, uuid
from bleak import BleakClient
from winrt.windows.devices.bluetooth import BluetoothDevice, BluetoothCacheMode
from winrt.windows.networking.sockets import StreamSocket
from winrt.windows.storage.streams import DataReader, InputStreamOptions
BLE="25:09:23:B6:31:8E"; CL=int("250923B631DB",16); SPP=uuid.UUID("00001101-0000-1000-8000-00805F9B34FB")
CH={"1102":"00001102-d102-11e1-9b23-00025b00a5a5","1103":"00001103-d102-11e1-9b23-00025b00a5a5",
    "ff14":"0000ff14-0000-1000-8000-00805f9b34fb","fff1":"0000fff1-0000-1000-8000-00805f9b34fb","2a19":"00002a19-0000-1000-8000-00805f9b34fb"}
T=time.time(); log=lambda *a: print(f"[{time.time()-T:5.1f}s]",*a,flush=True)
async def rfcomm():
    dev=await BluetoothDevice.from_bluetooth_address_async(CL)
    res=await dev.get_rfcomm_services_with_cache_mode_async(BluetoothCacheMode.UNCACHED)
    s=[x for x in res.services if uuid.UUID(str(x.service_id.uuid))==SPP][0]
    sock=StreamSocket(); await sock.connect_async(s.connection_host_name,s.connection_service_name)
    r=DataReader(sock.input_stream); r.input_stream_options=InputStreamOptions.PARTIAL
    log("RFCOMM conectado")
    while True:
        n=await r.load_async(256)
        if n==0: break
        b=bytearray(n); r.read_bytes(b); log("RFCOMM <-",bytes(b).hex())
async def ble():
    async with BleakClient(BLE,timeout=25) as c:
        for k,u in CH.items():
            try: await c.start_notify(u,lambda s,d,k=k: log("BLE",k,"<-",bytes(d).hex()))
            except Exception as e: log("BLE sub ERR",k,e)
        log("BLE inscrito")
        await asyncio.sleep(100)
async def main():
    t=[asyncio.ensure_future(rfcomm()),asyncio.ensure_future(ble())]
    await asyncio.sleep(2); log("PRONTO - TROQUE O ANC AGORA (100s)")
    await asyncio.wait(t[1:],timeout=110)
asyncio.run(main())

import asyncio, time
from bleak import BleakClient
ADDR="AA:BB:CC:DD:EE:01"
CH={"1102":"00001102-d102-11e1-9b23-00025b00a5a5","1103":"00001103-d102-11e1-9b23-00025b00a5a5",
    "ff14":"0000ff14-0000-1000-8000-00805f9b34fb","fff1":"0000fff1-0000-1000-8000-00805f9b34fb",
    "2a19":"00002a19-0000-1000-8000-00805f9b34fb"}
t0=time.time()
async def main():
    async with BleakClient(ADDR, timeout=25) as c:
        for k,u in CH.items():
            try:
                await c.start_notify(u, lambda s,d,k=k: print(f"[{time.time()-t0:5.1f}s] {k}: {bytes(d).hex()}", flush=True))
                print("ok",k, flush=True)
            except Exception as e: print("ERR",k,e, flush=True)
        print("ESCUTANDO 90s - mude o modo de ANC agora", flush=True)
        await asyncio.sleep(90)
asyncio.run(main())

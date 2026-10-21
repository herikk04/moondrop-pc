import asyncio
from bleak import BleakClient
ADDR="25:09:23:B6:31:8E"
async def main():
    async with BleakClient(ADDR, timeout=25) as c:
        for u in ["00002a19-0000-1000-8000-00805f9b34fb","0000ff15-0000-1000-8000-00805f9b34fb"]:
            try: print("read",u[4:8], (await c.read_gatt_char(u)).hex())
            except Exception as e: print("read",u[4:8],"ERR",e)
        for u in ["0000ff14-0000-1000-8000-00805f9b34fb","0000fff1-0000-1000-8000-00805f9b34fb"]:
            try:
                await c.start_notify(u, lambda s,d,u=u: print("notify",u[4:8],bytes(d).hex()))
                print("subscribed",u[4:8])
            except Exception as e: print("sub",u[4:8],"ERR",e)
        print("listening 20s (mude o ANC no fone/controle agora)...")
        await asyncio.sleep(20)
asyncio.run(main())

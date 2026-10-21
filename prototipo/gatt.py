import asyncio
from bleak import BleakClient
ADDR="25:09:23:B6:31:8E"
async def main():
    async with BleakClient(ADDR, timeout=25) as c:
        print("connected:", c.is_connected)
        for s in c.services:
            print("SERVICE", s.uuid, s.description)
            for ch in s.characteristics:
                print("   CHAR", ch.uuid, ch.properties)
asyncio.run(main())

import asyncio, sys
from bleak import BleakScanner
async def main():
    found = await BleakScanner.discover(timeout=12, return_adv=True)
    for addr,(d,adv) in sorted(found.items(), key=lambda x: -(x[1][1].rssi or -999)):
        name = d.name or adv.local_name or ""
        print(f"{addr}  rssi={adv.rssi:>4}  {name!r}  uuids={list(adv.service_uuids)}")
asyncio.run(main())

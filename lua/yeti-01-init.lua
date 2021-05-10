package.path = package.path ..";?.lua;test/?.lua;app/?.lua;"

require "Pktgen"

-- default pktgen initialization for yeti-00 server
-- full list of features can be found in `test/main.lua` in pktgen-dpdk repo

-- display
pktgen.screen('on')                                 --uncomment for debugging
pktgen.ports_per_page(2);


-- options for port 0
pktgen.set_mac("0", "dst","94:40:c9:8a:d6:fe");       -- yeti-00 enp59s0 intf
pktgen.set_ipaddr("0", "dst", "10.0.5.1");            -- yeti-00 enp59s0 intf


-- common for all ports
pktgen.set("all", "count", 0);                        -- forever
pktgen.set("all", "rate", 100);                       -- 100% of linkrate
pktgen.set("all", "size", 128);
pktgen.set("all", "burst", 1);

-- stop all ports and clear all stats
pktgen.stop("all")
-- pktgen.clear("all")


pktgen.pause("Refreshed pktgen!\n", 0);
-- pktgen.delay(1000);
-- pktgen.cls();

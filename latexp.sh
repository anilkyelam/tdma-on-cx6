#
# Controls pktgen apps for latency measurements with CX-6 NICs
#


txport=${txport:-0}
rxport=${rxport:-0}
txhost=${txhost:-yeti-00}
rxhost=${rxhost:-yeti-01}
sharedscdir=~/scratch       # Shared scratch directory that is available on both hosts (i.e., NFS) (make sure root can write to it on both hosts)
latfile=${sharedscdir}/latencies.dat


# Make sure pktgen is running on both sides
# If pktgen is up and properly configured, port 22022 should be open for accepting commands.
nc -z $txhost 22022
if [ $? -ne 0 ]; then 
    echo "ERROR! Pktgen did not initialize properly on tx host: $txhost"
    echo -e "$usage"
    exit 1
fi
nc -z $rxhost 22022
if [ $? -ne 0 ]; then 
    echo "ERROR! Pktgen on rx host: $rxhost is not initialized properly"
    echo -e "$usage"
    exit 1
fi

# Refresh/Re-initialize ports using init scripts
if [ -f lua/${txhost}-init.lua ]; then
    socat - TCP4:$txhost:22022 < lua/${txhost}-init.lua
fi
if [ "$rxhost" != "$txhost" ] && [ -f lua/${rxhost}-init.lua ]; then
    socat - TCP4:$rxhost:22022 < lua/${rxhost}-init.lua
fi

function pktgen_command { 
    local host=$1
    local command=$2
    echo $command | socat - TCP4:$host:22022 1> /dev/null 
}

function pktgen_reset_latsampler {
    local host=$1
    local port=$2
    local lattype=$3            # type of latency sampler: simple (packet-based)/poisson (time-based)
    local latcount=$4           # max number of samples
    local latrate=$5            # sampling rate (samples per sec if poission, packets per sample if simple)
    local latfile=$6            # file to write to
    pktgen_command $host 'pktgen.latsampler("'$rxport'", "stop")'           # stop sampler to reset it
    pktgen_command $host 'pktgen.latsampler_params("'$rxport'","'$lattype'","'$latcount'","'$latrate'","'$latfile'")'
    pktgen_command $host 'pktgen.latsampler("'$rxport'", "start")'          # start sampler
}

#
# # One-way latency data 
# (assuming that packet pacing and h/w timestamping features are enabled on the CX-6 NICs 
#  AND that pktgen has the my changes to latency sampler for using these features)
#

# Set latency sampler config (we need to start the sampler on tx host as well for it 
# to put timestamps in the packet, the actual params do not matter)
pktburst=1
pktgen_reset_latsampler $txhost $txport simple 10 1 $latfile 
pktgen_command $txhost 'pktgen.set("'$txport'", "burst", '$pktburst')'          # set pkt burst


# # Get latency of every packet
pktcount=200
pktgen_reset_latsampler $rxhost $rxport simple $pktcount 1 $latfile
pktgen_command $txhost 'pktgen.set("'$txport'", "count", '$pktcount')'      # set pkt count
pktgen_command $txhost 'pktgen.start("'$txport'")'                          # start sending
sleep 5  


# # Get latency with random poisson sampling (at full linkrate)
# pktgen_reset_latsampler $rxhost $rxport poisson 20000 1000 $latfile
# pktgen_command $txhost 'pktgen.set("'$txport'", "count", 0)'                # set pkt count to 0 (unlimited)
# pktgen_command $txhost 'pktgen.set("'$txport'", "rate", 100)'               # set pkt rate
# pktgen_command $txhost 'pktgen.start("'$txport'")'                          # start sending
# sleep 15                                                                    # Wait a bit


pktgen_command $txhost 'pktgen.stop("'$txport'")'                           # stop sending
pktgen_command $rxhost 'pktgen.latsampler("'$rxport'", "stop")'             # stop sampler to write results to file

mv $latfile .
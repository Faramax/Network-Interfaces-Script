BEGIN {

    start = 0;

    if (ARGC < 3 || ARGC > 5) {
        print "awk -f readInterfaces.awk <interfaces file> device=<eth device> [output=address|netmask|gateway|hwaddress|ip|all, default:ip] [debug=1]"
        exit 1;
    }

    outAll = 0          # all posible data
    outAddress = 0;     # address only
    outHwaddress = 0;   # hwaddress only
    outNetmask = 0;     # network only
    outGateway = 0;     # gateway only
    outIP = 1;          # default : address, network & gateway

    for (i = 2; i < ARGC; i++) {
        split(ARGV[i], arg, "=");
        if (arg[1] == "device")
            device = arg[2];
        else if (arg[1] == "output") {
            outIP = 0;
            if (arg[2] == "all")
                outAll = 1;
            else if (arg[2] == "address")
                outAddress = 1;
            else if (arg[2] == "netmask")
                outNetmask = 1;
            else if (arg[2] == "gateway")
                outGateway = 1;
            else if (arg[2] == "hwaddress")
                outHwaddress = 1;
            else if (arg[2] == "ip")
                outIP = 1;
        }
        else if (arg[1] == "debug" && arg[2] == "1")
            debug = 1;
    }

    if (!length(device)) {
        print "awk -f readInterfaces.awk <interfaces file> device=<eth device> [output=all] [debug=1]"
        exit 1;
    }
}

{
    # Look for iface line and if the interface comes with the device name
    # scan whether it is dhcp or static or manual
    # e.g. iface eth0 inet [static | dhcp | manual]
    if ($1 == "iface")  {
        # Ethernet name matches - switch the line scanning on
        if ($2 == device) {
            if (debug)
                print $0;
            # It's a DHCP interface
            if (match($0, / dhcp/)) {
                print "dhcp";
                gotTypeNoAddr = 1;
                exit 0;
                # It's a static network interface. We want to scan the
                # addresses after the static line
            }
            else if (match ($0, / static/)) {
                static = 1;
                next;
            }
            else if (match ($0, / manual/)) {
                print "manual";
                gotTypeNoAddr = 1;
                exit 0;
            }
            # If it is other inteface line, switch it off
            # Go to the next line
        }
        else {
            static = 0;
            next;
        }
    }
    else if ($1 == "auto") {
        static = 0;
        next;
    }

    # At here, it means we are after the iface static line of
    # after the device we are searching for
    # Scan for the static content
    if (static) {
        # 2nd field to end of the line
        if (length($1)) {
            interface[$1] = substr($0, index($0, $2));
            gotAddr = 1;
        }
    }
}

END {
    if (gotAddr) {
        if (outAddress)
            printf("%s\n", interface["address"]);
        else if (outNetmask)
            printf("%s\n", interface["netmask"]);
        else if (outGateway)
            printf("%s\n", interface["gateway"]);
        else if (outIP)
            printf("%s %s %s\n", interface["address"], interface["netmask"], interface["gateway"]);
        else if (outHwaddress)
            printf("%s\n", interface["hwaddress"]);
        else if (outAll) {
            for (field in interface) {
                printf("%s %s\n", field, interface[field]);
            }
        }
        exit 0;
    }
    else {
        if (gotTypeNoAddr)
            exit 0;
        else
            exit 1;
    }
}

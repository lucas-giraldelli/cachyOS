function vpn-restart
    pkill -f "openvpn-connect-linux" 2>/dev/null
    sleep 1
    openvpn-connect &
    disown
    echo "OpenVPN Connect restarted"
end

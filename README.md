# luci-app-pptp-server
my version of pptpd UI for OpenWRT
Generated with AI (I dont know LUA :/)


# Install packages
opkg update
opkg install ppp-mod-pptp kmod-nf-nathelper-extra


# Configure kernel parameters
cat << EOF >> /etc/sysctl.conf
net.netfilter.nf_conntrack_helper=1
EOF
service sysctl restart

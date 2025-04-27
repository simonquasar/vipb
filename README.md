![Static Badge](https://img.shields.io/badge/VIPB-Versatile%20IP%20Blacklister-orange?logo=backblaze&logoColor=goldenrod&color=red)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/simonquasar/vipb)
![GitHub top language](https://img.shields.io/github/languages/top/simonquasar/vipb)
![GitHub Release](https://img.shields.io/github/v/release/simonquasar/vipb)
![GitHub commits since latest release](https://img.shields.io/github/commits-since/simonquasar/vipb/latest)


# VIPB - Versatile IP Blacklister

**VIPB (Versatile IP Blacklister)** is a robust Bash tool for downloading, processing, and maintaining [*IPsum*](https://github.com/stamparm/ipsum/) blacklists, and provides functionalities for managing firewalls and IP blacklists through automated and manual processes. It seamlessly integrates with Linux firewalls: it uses `ipset` along with `iptables` or `firewalld` (`ufw` support coming soon..). 
It includes daily automation via `cron` job and integration with `fail2ban`.

## Features

### Automated & Manual IP Ban

- **Daily Download & Ban**: Automatically download and process [*IPsum*](https://github.com/stamparm/ipsum/) blacklists every day via `cron` job.
- **Bulk Ban IP Lists**: Process entire lists of IPs and subnets from a list file.
- **Manual IP ban**: Ban/unban individual IP addresses on a separate user list.
- **Simplified Firewall Management**: Safer handling of FirewallD and ipset operations
- **New Log Extractor**: Advanced security event analysis and pattern recognition

### Aggregator: Suspicious IPs to Subnets

- **IP Compression**: Optimize IP lists into /16 and /24 subnets for efficient security.

This function analyzes a list of potentially suspicious IP addresses, identifies patterns of repeated activity within subnets, and aggregates them into entire subnets (/24 or /16) based on user-defined tolerance thresholds.

### Firewall Integration

- **Manage ipsets**: Creates and manages `ipset` rules for swift and reliable IP blocking.
- **Linux Firewall Support**:
`iptables`
`firewalld`
(`ufw` support coming soon)
- **Fail2Ban**: Works in harmony with `Fail2Ban`.

## Installation

Ensure required dependencies are installed and active:

- `ipset` 7.0+
- `firewalld` or `iptables`
- `cron`
- `curl`
- `bash` 4.0+
- *optional* `fail2ban`

Clone the repository:

```bash
git clone https://github.com/simonquasar/vipb
cd vipb
chmod +x vipb.sh vipb-core.sh
```

## Usage

### User Interface
Run `sudo ./vipb.sh`

![VIPB UI](https://github.com/simonquasar/vipb/blob/main/inc/ScreenshotVIPB.png)
> [!NOTE]  
> IP lists should be in the same folder and use `.ipb` extension, with one IP per line in [CIDR](https://www.ipaddressguide.com/cidr) notation.


### CLI Commands

Run via CLI/cron `sudo ./vipb.sh [args]`

````
► VIPB.sh (v0.9) CLI ARGUMENTS

  ban #.#.#.#               ban single IP in manual/user list
  unban #.#.#.#             unban single IP in manual/user list
  download #                download lv #
  compress [listfile.ipb]   compress IPs list [optional: file.ipb]
  banlist [listfile.ipb]    ban IPs/subnets list [optional: file.ipb]
  stats                     view banned VIPB IPs/subnets counts
  true                      simulate cron/CLI (or autoban)
  debug                     debug mode (echoes logs)

                            (*.ipb = list of IPs, one per line)                        
````

### Logs

All operations are logged in the script directory.
Debug mode provides detailed operation logging.

## Contributing

Contributions are welcome! Feel free to submit pull requests or open issues for bugs and feature requests.

## License

This project is licensed under the GPL-2.0 License. See the LICENSE file for details.

## Credits

- *IPsum* project for IP reputation data [<https://github.com/stamparm/ipsum/>]
- *Alexander Klimetschek* & *miu* for menu selectors [<https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu>]
- Initial development by [simonquasar](https://simonquasar.net/)

## Note

> [!CAUTION]  
> This tool is designed for "domestic" server protection. Please use responsibly and ensure you know the implications of firewalling / IP blocking in your environment before using this script.
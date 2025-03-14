![Static Badge](https://img.shields.io/badge/version-0.9beta-orange)
![GitHub top language](https://img.shields.io/github/languages/top/simonquasar/vipb)
![GitHub commit activity](https://img.shields.io/github/commit-activity/t/simonquasar/vipb)

> [!IMPORTANT]  
> Mar '25: Currently developing 0.9beta4 to a "stable" 0.9 release.
> 
> 2do:
> - final check on firewall rules/setup (Menu 6.)

# VIPB - Versatile IP Blacklister

**VIPB (Versatile IP Blacklister)** is a little tool written in Bash automates for downloading, processing, and maintaining [*IPsum*](https://github.com/stamparm/ipsum/) blacklists, and provides functionalities for firewall, ban, and log management. It uses `ipset` with `iptables` or `firewalld` (`ufw` coming soon..). It includes automation via `cron` jobs, integration with `fail2ban`, and a user-friendly interface for manual operations.

## Features

### Automated & Manual IP Ban

- **Ban IP Lists and/or Subnets**: Ban individual IPs, /16, and /24 subnets from a file.
- **Dynamic Updates**: Automatically download and process IP blacklists from [*IPsum*](https://github.com/stamparm/ipsum/).
- **Dual Blacklists**: Maintains separate lists and ipsets for automated and manual IP bans.

### Suspicious IPs to Subnets Aggregator

This function analyzes a list of potentially suspicious IP addresses, identifies patterns of repeated activity within subnets, and aggregates them into entire subnets (/24 or /16) based on user-defined tolerance thresholds.

### Daily Ban Automation (via Cron Jobs)

- **Daily Download & Ban**: Automated daily IPsum list download and ban via cron jobs.

### Firewall Integration

- **Manage `ipset`**: Creates and manages `ipset` rules for swift IP blocking.
- **Firewalls & Rules**: Integrates with both `firewalld` and `iptables` (`ufw` coming soon).
- **Fail2Ban**: Works in harmony with `Fail2Ban`.

## CLI

Run via CLI `./vipb.sh args`

````
► VIPB.sh (v0.9beta4) CLI ARGUMENTS

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

## Installation

Ensure required dependencies are installed and active:

- `ipset`
- `firewalld` or `iptables`
- `cron`
- `curl`
- `bash` 4.0+
- *optional* `fail2ban`
- *optional* `figlet`

Clone the repository:

```bash
git clone https://github.com/simonquasar/vipb
cd vipb
```

Make the scripts executable:

```bash
chmod +x vipb.sh vipb-core.sh
```

## Logs

Operation logs are stored in the script directory.

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## License

This project is licensed under the GPL-2.0 License. See the LICENSE file for details.

## Credits

- *IPsum* project for IP reputation data [<https://github.com/stamparm/ipsum/>]
- *Alexander Klimetschek* & *miu* for menu selectors [<https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu>]
- Initial development by [simonquasar](https://simonquasar.net/)

## Note

This tool is designed for "domestic" server protection. Please use responsibly and ensure you know the implications of firewalling / IP blocking in your environment.

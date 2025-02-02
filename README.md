![Static Badge](https://img.shields.io/badge/version-0.9beta-orange)
![GitHub top language](https://img.shields.io/github/languages/top/simonquasar/vipb)
![GitHub commit activity](https://img.shields.io/github/commit-activity/t/simonquasar/vipb)

> [!IMPORTANT]  
> Feb '25: Currently developing 0.9beta to a "stable" 0.9 release.
> - Adding Geo IP lookup option (using `geoiplookup` or `whois`)
>   
> 2do:
> - better `check_dependencies()`
> - better use `ban_ip()` along with `check_firewall_rules()`
> - various 2dos in `vipb-ui.sh`

# VIPB - Versatile IP Blacklister

Welcome to **VIPB (Versatile IP Blacklister)** – a comprehensive tool written in Bash for protecting your VPS Linux server from malicious sources using `ipset` with `iptables` or `firewalld`. It includes automation via `cron` jobs, integration with `fail2ban`, and a user-friendly interface for manual operations.

**VIPB** automates downloading, processing, and maintaining [*IPsum*](https://github.com/stamparm/ipsum/) blacklists, and provides functionalities for firewall, ban, and log management.

## Features

### Automated & Manual IP Ban

- **Ban IP Lists and Subnets**: Ban individual IPs, /16, and /24 subnets from a file.
- **Dynamic Updates**: Automatically download and process IP blacklists from [*IPsum*](https://github.com/stamparm/ipsum/).
- **Threat Level Control**: Supports multiple suspicious occurrences levels (2-8).
- **Suspicious Subnets Generator**: Aggregates individual IPs into "suspicious" subnet ranges (/16 and /24).
- **Dual Blacklists**: Maintains separate lists and ipsets for automated and manual IP bans.

### Suspicious IPs to Subnets Aggregator

This function analyzes a list of potentially suspicious IP addresses, identifies patterns of repeated activity within subnets, and aggregates them into entire subnets (/24 or /16) based on user-defined tolerance thresholds.

### Daily Ban Automation (Cron Jobs)

- **Daily Download & Ban**: Automated daily IPsum list download and ban via cron jobs.
- Command-line interface for easy automation.

### Firewall Integration

- **Manage `ipset` Rules**: Creates and manages `ipset` rules for swift IP blocking.
- **Dual Integration**: Integrates with both `firewalld` and `iptables` (as fallback).
- **Fail2Ban Integration**: Works in harmony with `Fail2Ban`.

### Log Management

- **Read Common Log Files**: View logs from `auth.log`, `fail2ban.log`, etc.

### User Interface

- **Interactive Terminal UI**: User friendly and easy-to-use linux cli for all operations with status updates and counters.

## Usage

### Execute

Launch the interactive interface or cron jobs and automation:

```bash
./vipb.sh
```

## Functions

1. **Download IPsum Blacklist**
   - Choose threat level (2-8).

2. **Blacklist Compression**
   - Aggregates IP lists into subnet ranges, creating /24 and /16 suspicious subnets lists.

3. **Ban via Ipsets**
   - Apply IP bans from different source lists (also user defined).
   - Choose between original IP lists or the optimized subnets.
   - View and manage active ipsets.

4. **Manual/User Ban**
   - Add individual IPs to manual blacklist.
   - View and remove manually banned IPs.
   - Export manual bans to a list file.

5. **Cron Jobs**
   - Set up automated daily updates.
   - Configure blacklist download schedule.
   - Manage automated ban operations.

6. **Firewall Rules**
   - Manage and refresh related firewall rules.
   - Check integration status.

7. **Logs & Info**
   - View related system and operation logs.

8. **Geo IP lookup**
   - Lookup geographical infos of given IPs.
     
## Configuration

No real configuration is needed. 

## Installation

Ensure required dependencies are installed:

- `ipset`
- `firewalld` or `iptables`
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

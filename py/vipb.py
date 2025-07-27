import subprocess
import os
import re

class VIPB:
    def __init__(self):
        self.ver = "v0.9.4"
        self.blacklist_file = 'vipb-blacklist.ipb'
        self.optimized_file = 'vipb-optimized.ipb'
        self.subnets24_file = 'vipb-subnets24.ipb'
        self.subnets16_file = 'vipb-subnets16.ipb'
        self.blacklist_level = 4
        self.exit_code = 0

    def log(self, message):
        """Log messages to a log file."""
        with open("vipb-log.log", 'a') as log_file:
            log_file.write(f"{message}\n")

    def check_debug_mode(self):
        """Check if debug mode is enabled based on args."""
        import sys
        args = sys.argv[1:]
        if 'debug' in args:
            self.log("DEBUG MODE ON")
            args.remove('debug')

    def download_ipsum(self, level):
        """Download IPsum list."""
        url = f"https://raw.githubusercontent.com/stamparm/ipsum/master/levels/{level}.txt"
        result = subprocess.run(['curl', '-o', self.blacklist_file, url], capture_output=True, text=True)
        if result.returncode != 0:
            print(f"Error downloading list: {result.stderr}")
            self.exit_code = 1
        else:
            print(f"Downloaded IP list at level {level}.")

    def run(self):
        self.check_debug_mode()  # Check for debug mode from args
        self.download_ipsum(self.blacklist_level)

if __name__ == "__main__":
    vipb = VIPB()
    vipb.run()
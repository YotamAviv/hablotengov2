#!/usr/bin/env python3
import argparse
import subprocess
import sys
import time
import signal
import os

def run_chrome_widget(target_file, is_headless, dart_defines=None):
    cmd = [
        "flutter", "run",
        "-d", "chrome",
        "-t", target_file
    ]

    for define in (dart_defines or []):
        cmd += ["--dart-define", define]

    if is_headless:
        cmd.append("--web-browser-flag=--headless")
    
    print(f"Starting Chrome Widget Runner: {' '.join(cmd)}")
    # Launch in a new process group so we can cleanly kill the entire child tree later
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, preexec_fn=os.setsid)
    
    success = False
    finished = False
    
    # Read output line by line
    for line in iter(process.stdout.readline, ''):
        print(line, end='')
        if "PASS" in line:
            success = True
            finished = True
            break
        elif "FAIL" in line:
            success = False
            finished = True
            break
        elif "ERROR" in line:
            success = False
            finished = True
            break

    if finished:
        print("\n[Widget Completed] Shutting down widget runner...")
        time.sleep(1)
            
        # Send SIGTERM to the entire process group (Flutter + Dart + Chrome)    
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)
        except ProcessLookupError:
            pass
            
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(os.getpgid(process.pid), signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
        
        return success
    
    return process.returncode == 0

def main():
    parser = argparse.ArgumentParser(description="Chrome Widget Test Runner")
    parser.add_argument("-t", "--target", required=True, help="Target dart file to compile and run.")
    parser.add_argument("--headless", action="store_true", help="Launch Chrome invisibly for CI environments.")
    parser.add_argument("--dart-define", action="append", dest="dart_defines", default=[], metavar="KEY=VALUE", help="Pass --dart-define to flutter run (repeatable).")
    args = parser.parse_args()

    print(f"\n==============================================")
    print(f"Launching Chrome Widget Runner...")
    print(f"==============================================\n")

    success = run_chrome_widget(args.target, args.headless, args.dart_defines)
    os.system('stty sane')
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()

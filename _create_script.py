#!/usr/bin/env python3
script = """#!/bin/bash
export PATH="/mnt/c/dev/flutter/bin:$PATH"
cd /home/horie/projects/takamagahara/utsushiyo/rpg-task
flutter analyze 2>&1
"""
with open('/home/horie/projects/takamagahara/utsushiyo/rpg-task/_run_analyze.sh', 'w') as f:
    f.write(script)
import os
os.chmod('/home/horie/projects/takamagahara/utsushiyo/rpg-task/_run_analyze.sh', 0o755)
print('done')

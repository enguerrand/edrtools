#!/bin/bash
failed_unit_count=$(systemctl --failed  | grep "units listed" | grep -o "^[0-9]* ")
[ ${failed_unit_count:-0} -eq 0 ] && exit 0
systemctl --failed >&2
exit 1

#!/bin/bash
# Synthesis workspace cleanup script
rm -rf genus.log* genus.cmd*
rm -rf outputs/* outputs_dft/* reports/* fv
echo "Synthesis run directories cleaned."

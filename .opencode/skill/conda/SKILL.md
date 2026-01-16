---
name: conda 
description: Instructions for correct conda usage in opencode
---

# What I do
Correctly utilize conda environments to run python code

# When to use me
When you are asked to run python code. You should ask the user which conda enviroment is the correct one to use, and then correctly use the commands listed below to accomplish the task.

When using conda commands in opencode, always prepend the sourcing of conda's profile script to ensure the shell has conda's functions loaded. Opencode runs bash commands in non-interactive shells, which do not automatically source ~/.bashrc or load conda initialization.

For any conda command, such as activation, installation, or environment management, use this format:
source ~/miniconda3/etc/profile.d/conda.sh && conda <command> <args>

Examples:
- To activate an environment: source ~/miniconda3/etc/profile.d/conda.sh && conda activate arxiv
- To install a package: source ~/miniconda3/etc/profile.d/conda.sh && conda install numpy
- To create an environment: source ~/miniconda3/etc/profile.d/conda.sh && conda create -n myenv python=3.9

This ensures conda works correctly despite the non-interactive shell limitation.
For ease of ensuring consistency with the code, you should never try to install a package nor create an environment without explicit instructions.
You can activate environments, but you should first clarify with the user that the environment is the correct one.
You should assume that all necessary packages are installed in the conda environment that the user specifies.
NEVER try to alter PYTHONPATH. The project should always be configured to correctly run things. If you have questions, ask the user.
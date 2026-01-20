# Import More Configuration

## Goal

1. Scan the ~/ home folder looking for any common environment configuration files. Include XDG and other common tool folders or file paths. Iignore mac folders like Documents, Downloads, etc.
2. Find any files that are not in the optimum XDG locations. Propose a plan to move them there. Include any new environment variables needed.The arch linux wiki has a very good site that describes common tool setups to meet XDG ([text](https://wiki.archlinux.org/title/XDG_Base_Directory)).
3. Find any configuration that belongs in the dotfiles repo but is not present. Create a plan that combines changes from step 2 and 3 so that the environment files can be added to the repo and restructured to fit best practices.
4. As a final step, look for any installed packages using tools that should have been installed differently (e.g. npm instead of npx; pip instead of pip instead of pipx; downloaded instead of brewed).

## Approach

Use /note along the way to write out progress so that separate claude sessions can resume.

## Output

Ask questions iterative and as needed. Present the plan and be ready to show steps to move things iteratively. Tests will be needed for each config change.

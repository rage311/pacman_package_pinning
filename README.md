Place the "package_pinning.hook" file in your pacman hooks directory:

    /etc/pacman.d/hooks/package_pinning.hook

Edit the package_pinning.hook file lines:

    Target = your-package-target # e.g. linux-zen
    Exec = /path/to/pacman_package_pinning_hook.pl --package "your-package" --repo "your-package's-repo" --pin "your-pin-specifier-(see-below)"

Options for `pin` argument:

"minor", "major", ^MAJOR, ~MAJOR.MINOR, =MAJOR.MINOR.PATCH, <MAJOR.MINOR.PATCH  
"minor": pins package to currently installed minor version. e.g. "minor"  
"major": pins package to currently installed major version. e.g. "major"  
^: pins to specified MAJOR version. e.g. ^6.7.8 will pin to 6.X.Y  
~: pins to specified MAJOR.MINOR version. e.g. ~6.7.8 will pin to 6.7.X  
=: pins to exact specified MAJOR.MINOR.PATCH version. e.g. =6.7.8 will pin to 6.7.8  
<: pins to a version less than specified MAJOR.MINOR.PATCH version. e.g. <6.7.8 will pin from 0.0.0 up to 6.7.7  

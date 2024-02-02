#Split and Document PL/SQL
This set of scripts was borne out need. I recently joined a project where packages were stored with their Specifications and Bodies in the same file. 

Storing them in separate files is not just a preference, but fairly important when it comes to working on larger projects where there may be a lot of cross referencing of packages. 

By keeping the SPEC and BODY separate, you're able to compile all specifications first, then compile bodies that may reference other packages, without worrying whether the referenced package has been fully compiled or not. 

##Scritps
###split_and_doc.py
`split_and_doc.py` is a python program that takes 1 (one) parameter - The name of a PL/SQL file that has both the SPEC and the BODY of a PL/SQL Package. 

It will output 2 (two) files
<<infile_name>>.pks - the package specification
<<infile_name>>.pkb - the package body

It will also parse both the SPEC and BODY looking for FUNCTIONS and PROCEDURES and will create `javadoc` style documentation and insert it just before the appropriate PROCEDURE|FUNCTION. 

####Assumptions
The only assumption made here is that the file contains both a SPEC and a BODY that are ended by a forward slash (`/`) on a single line.

###Process_pck_files.sh
I also created a shell script that walks through all `*.pck` files in the current directory and runs the python script for each. 

*NOTE*: the script contained in this repository was created for the Oh My Z (zsh) shell, but could easily be adapted for bash or any other shell of your choice. 

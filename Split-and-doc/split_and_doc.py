import re
import sys
import os

def parse_parameters(proc_or_func_text):
    """
    Parse parameters from the procedure or function definition.

    :param proc_or_func_text: The text of the procedure or function.
    :return: A list of tuples with parameter names and types.
    """
    param_pattern = r'\s*(\w+)\s+(\w+[\s\w]*)'
    params = re.findall(param_pattern, proc_or_func_text)
    return params

def create_javadoc(proc_or_func_name, params, return_type=None):
    """
    Create Javadoc style documentation for a procedure or function.

    :param proc_or_func_name: The name of the procedure or function.
    :param params: The list of parameters (name, type).
    :param return_type: The return type if it's a function.
    :return: A string with the Javadoc documentation.
    """
    javadoc  = "/* ------------------------------------------------------------------------------\n"
    javadoc += f"   * {proc_or_func_name}\n"
    javadoc += "   * ------------------------------------------------------------------------------\n"
    for param in params:
        javadoc += f"   * @param {param[0]} {param[1]}\n"
    if return_type:
        javadoc += f"   *\n   * @return {return_type}\n"
    javadoc += "   * ------------------------------------------------------------------------------\n"
    javadoc += "   */\n"
    return javadoc

def print_proc_or_func(proc_or_func, name, params, return_type=None):
    """
    Print the procedure or function with its parameters and return type to stdout.

    :param proc_or_func: The type (PROCEDURE or FUNCTION).
    :param name: The name of the procedure or function.
    :param params: The list of parameters (name, type).
    :param return_type: The return type if it's a function.
    """
    print(f"{proc_or_func} {name}")
    for param in params:
        print(f"  Parameter: {param[0]} Type: {param[1]}")
    if return_type:
        print(f"  Return Type: {return_type}")
    print()

def separate_spec_and_body(package_content):
    """
    Separate the package specification and body from the combined content.

    :param package_content: The combined text of the specification and body.
    :return: A tuple containing the specification and body text.
    """
    parts = re.split(r'^/\s*$', package_content, flags=re.MULTILINE)
    return parts[0].strip(), parts[1].strip()

def process_package_content(package_content, package_type):
    """
    Process the package content, adding documentation to spec or body.

    :param package_content: The text of the package spec or body.
    :param package_type: A string indicating 'PACKAGE' or 'PACKAGE BODY'.
    :return: Modified package content with documentation.
    """
    # Regex pattern to find procedures and functions
    proc_func_pattern = re.compile(
        rf'(?P<before>(?:\n\s*|^))(FUNCTION|PROCEDURE)\s+(?P<name>\w+)\s*\((?P<params>.*?)\)\s*(RETURN\s+(\w\.?)+)?\s*(PIPELINED)?(IS|AS)?',
        re.IGNORECASE | re.DOTALL
    )

    # Function to perform the replacement using the match object
    def replace_with_javadoc(match):
        proc_or_func = match.group(2)  # FUNCTION or PROCEDURE
        name = match.group('name')
        params_text = match.group('params')
        return_clause = match.group(5) or ''  # RETURN clause or empty string
        before = match.group('before')  # Whitespace or newline before the declaration
        pipelined = match.group(7) or '' # PIPELINE KEYWORD
        as_is = match.group(8) or '' # AS|IS keyword
        cr = '\n'

        params = parse_parameters(params_text)
        return_type = return_clause.replace('RETURN', '').strip() if return_clause else None

        # Print to stdout
        print_proc_or_func(proc_or_func.strip(), name, params, return_type)

        # Create Javadoc
        javadoc = create_javadoc(name, params, return_type)

        # Construct the full replacement text
        replacement = f"{before}{javadoc}{proc_or_func} {name}({params_text}){cr}{return_clause}{cr if len(pipelined) > 0 else ''}{pipelined}{cr if len(as_is) > 0 else ''}{as_is}"

        return replacement

    # Perform the replacement in the package content
    package_content = proc_func_pattern.sub(replace_with_javadoc, package_content)

    return package_content

def main(input_filename):
    try:
        base_filename, _ = os.path.splitext(input_filename)
        spec_filename = f"{base_filename}.pks"
        body_filename = f"{base_filename}.pkb"

        with open(input_filename, 'r') as file:
            package_content = file.read()

        package_spec, package_body = separate_spec_and_body(package_content)

        # Process Package Specification
        package_spec = process_package_content(package_spec, 'PACKAGE')

        # Process Package Body
        package_body = process_package_content(package_body, 'PACKAGE BODY')

        # Write the modified package spec to the output file
        with open(spec_filename, 'w') as file:
            file.write(package_spec)

        # Write the modified package body to the output file
        with open(body_filename, 'w') as file:
            file.write(package_body)

        print(f"Documentation has been added. Spec output written to {spec_filename}")
        print(f"Documentation has been added. Body output written to {body_filename}")

    except IOError as e:
        print(f"An error occurred: {e.strerror}")



if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py ")
        sys.exit(1)

    input_file = sys.argv[1]
    main(input_file)

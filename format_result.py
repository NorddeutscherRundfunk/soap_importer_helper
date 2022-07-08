"""Reads importer's result file and formats in a better readable manner.

Usage:
python3 format_result.py
    --result result.txt
    --type "[HTML|JSON|XML]"
"""
import argparse
import os.path
import xml.etree.ElementTree as ElemTree


def parse_command_line_arguments():
    """Processes command line parameters.
    """
    parser = argparse.ArgumentParser(description='Behandlung einer einzelnen Feed-Instanz: Download, Validierung, etc.')

    parser.add_argument('-r', '--result', metavar='Text file with importer\'s result', dest='result_filename_with_path',
                        action='store', required=True, help='Text file that contains importer\'s result.')
    parser.add_argument('-t', '--type', metavar='File type of result.txt', dest='file_type', action='store',
                        required=True, help='File type: [XML|JSON|UNKNOWN]')

    return parser.parse_args()


def write_file(complete_path, contents):
    try:
        with open(complete_path, "w") as fo:
            fo.write(contents)
    except IOError:
        print('ERROR: File could not be written: {}'.format(complete_path))


def parse_xml(file):
    inner_xml = ""

    if os.path.isfile(file):
        # Parse outer XML
        tree_outer_xml = ElemTree.parse(file)
        root_outer_xml = tree_outer_xml.getroot()

        for n in root_outer_xml.findall('.//return'):
            inner_xml = n.text

        # Write inner XML to file:
        absolute_path_of_input_file_including_file_name = os.path.abspath(file)
        absolute_path_of_input_file = os.path.dirname(absolute_path_of_input_file_including_file_name)
        write_file(os.path.join(absolute_path_of_input_file, 'result_inner_xml.xml'), inner_xml)

        # Parse inner XML preflight
        # If `result.txt` contains 'errorText /' then the import was successful
        import_successful = False
        if 'errorText /' in inner_xml:
            import_successful = True

        # Parse inner XML
        root_inner_xml = ElemTree.fromstring(inner_xml)
        print('originalFileName:')
        print(str(root_inner_xml.find('.//{http://www.sophoracms.com/importinformation}originalFileName').text) + '\n')
        print('importFile:')
        print(str(root_inner_xml.find('.//{http://www.sophoracms.com/importinformation}importFile').text) + '\n')
        if not import_successful:
            print('errorText:')
            print(str(root_inner_xml.find('.//{http://www.sophoracms.com/importinformation}errorText').text) + '\n')
            print('Import contains error')
        else:
            print('Import without errors')
    else:
        print('ERROR: File {} does not exist.'.format(file))


def main():
    args = parse_command_line_arguments()
    if args.file_type.upper() == 'XML':
        parse_xml(args.result_filename_with_path)
    elif args.file_type.upper() == 'JSON':
        print('Treatment of importer result in JSON format not implemented yet.')
        print('This probably means that authentication with the importer failed.')
    elif args.file_type.upper() == 'HTML':
        print('Uh, did not expect importer result to be HTML.')
        print("Seems as if the importer can't be reached.")
        print("Maybe it's your current network settings (maybe you are using VPN but the proxy environment variables are not set)?")
        print('Or the importer might actually be down right now.')
    else:
        print('Unknown format. Should either be XML or JSON.')
        print('Check result file for further hints as to what went wrong:')
        print(os.path.abspath(args.result_filename_with_path))


if __name__ == '__main__':
    main()

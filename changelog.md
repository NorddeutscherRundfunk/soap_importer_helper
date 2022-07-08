# Changelog

## v0.3

- Refactored bash script variable *IMPORTER_INSTANCE* to *ENVIRONMENT* (e. g. *[dev|qa|prod|test]*)
- Refactored bash script variable *TARGET_CMS* to *CMS*
- Refactored filename `sample.TARGET_CMS.IMPORTER_INSTANCE.cfg` to `sample.CMS_ENVIRONMENT.cfg`
- Refactored bash script variable *NIMEX_DIR* to *SESSION_DIR*
- Created wiki article https://confluence.osc.ndr-net.de/display/TS/SOAP+Importer+Helper 


## v0.2

- Refactored `import_xml_to_sophora_via_soap.sh` to `import.sh`


## v0.1

- Added `changelog.md`
- Added `version.txt` (see header of `import_xml_to_sophora_via_soap.sh`)

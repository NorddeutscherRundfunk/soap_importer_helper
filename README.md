# SOAP-Importer-Helper

Takes NIMEX formatted XML file (= NIMEX input file) and imports it into Sophora using Sophora's own SOAP importer.
The NIMEX input file may be provided as a file in the local file system or via URL.

See section *Quick start*.



## Use cases

- Import XML as is from URL
- Import XML as is from file
- Import XML and add time stamp (so that changes can be spotted easily)




## Prerequisites

- macOS or "OS X" (should work on Linux as well, but needs a little adjustment. See section *Troubleshooting / Placeholders not replaced*)
- curl





## Quick start

- Set up config file for importer instance to be used in `config/importer/<CMS>_<ENVIRONMENT>.cfg` (only once for each combination of <CMS> and <ENVIRONMENT>).
  - If you need another combination of *CMS* and *ENVIRONMENT* you must create your own configuration: 
    - You can copy the default configuration `sample.CMS_ENVIRONMENT.cfg` to something like `unified_dev.cfg` (depending on <CMS> and <ENVIRONMENT>).
    - Next, you have to fill in the right values on the right side of the equal sign.
- Set up config file for context in `config/context/<CONTEXT>.cfg`. 
    - Each context label must be unique. 
	    - A context label must not contain space characters.
- Provide context-specific  SOAP-XML header and footer files:
    - `config/context/<CONTEXT>/templates/soap_envelope/header.xml`
    - `config/context/<CONTEXT>/templates/soap_envelope/footer.xml`
- Provide an ultra short description about this context in `config/context/<CONTEXT>/about.md`.
    - Example: *Importing CMS A NIMEX into CMS B to find and squash import bugs.* 
- Provide URL or file of NIMEX source.
- If using **SOAP Importer Helper** behind a proxy (e. g. within company's VPN): 
	- Specify proxy server (and credentials if necessary) in `config/set_vpn_proxy.sh`.
- If not using **SOAP Importer Helper** behind a proxy:
    - Change the following line in `import.sh`<br/>
      from<br/>
      `${SCRIPT_PATH}/config/set_vpn_proxy.sh`<br/>
      to<br/>
      `#${SCRIPT_PATH}/config/set_vpn_proxy.sh`
- cd to directory containg `import.sh`.
- Invoke:
    - Usage:  `$ ./import.sh <NIMEX-FILE> <CONTEXT> <CMS> <ENVIRONMENT>`
    - Example: `$ ./import.sh /tmp/test/sportschau_test.xml bugfixing sportschau qa`
    - Hint: <NIMEX-FILE> must either be specified by full path and filename or by URL.





## Example output

```
NIMEX_INPUT = https://www.tagesschau.de/kommentar/tankrabatt-103~nimex13.xml
Assuming NIMEX_INPUT is a URL
CONTEXT = ts_import_test
CMS = tagesschau
ENVIRONMENT = dev
CONTEXT_CONFIG_FILE = /Users/ts/soap_importer_helper/config/context/ts_import_test/config.cfg
NIMEX_DIR = /Users/ts/soap_importer_helper/sessions/ts_import_test/2022-06-16_001608
NIMEX_FILE = /Users/ts/soap_importer_helper/sessions/ts_import_test/2022-06-16_001608/nimex_input.xml
SOAP_ENVELOPE_TMP = /Users/ts/soap_importer_helper/sessions/ts_import_test/2022-06-16_001608/soap_envelope_tmp.xml
SOAP_ENVELOPE = /Users/ts/soap_importer_helper/sessions/ts_import_test/2022-06-16_001608/soap_envelope.xml
IMPORTER_CONFIG_FILE = /Users/ts/soap_importer_helper/config/importer/tagesschau_dev.cfg
CURL_NETRC_FILE = /Users/ts/soap_importer_helper/config/importer/curl/tagesschau_dev.netrc.cfg
CURL_CONFIG_FILE = /Users/ts/soap_importer_helper/sessions/ts_import_test/2022-06-16_001608/curl_config.cfg
originalFileName:
ws_1655331368553_66.xml

importFile:
/import/ws_1655331368553_66_2022-06-16_00-16-11-563.xml

errorText:
[2022-06-16 00:16:11,548, Warning] com.subshell.sophora.importer.XmlImporter:452: Die Vorverarbeitung für die Date /import/temp/ws_1655331368553_66.xml ist fehlgeschlagen.
com.subshell.sophora.importer.preprocessing.PreProcessingException: com.subshell.sophora.importer.preprocessing.PreProcessingException: No Nimex 1.4 story found in the input xml.
        at com.subshell.sophora.importer.preprocessing.PreProcessor.preprocess(PreProcessor.java:60)
		...
        at java.base/java.lang.Thread.run(Thread.java:829)
Caused by: com.subshell.sophora.importer.preprocessing.PreProcessingException: No Nimex 1.4 story found in the input xml.
		...
        at com.subshell.sophora.importer.preprocessing.PreProcessor.preprocess(PreProcessor.java:56)
        ... 12 more

Import contains error
```




## How it works

### In a nutshell

- Reads config files
- Assembles necessary files:
	- Config for curl (.netrc for credentials)
	- Config for curl (for performing POST request)
	- XML for importer
- Sends POST request to SOAP Importer
- Stores all files that were used while importing in the **sessin directory**: `sessions/CONTEXT/TIMESTAMP/` 
- Stores importer's answer in `sessions/CONTEXT/TIMESTAMP/result.txt` (with *CONTEXT* and *TIMESTAMP* being placeholders for acutal values)



### A more detailed view



#### SOAP importer configuration

The importer configuration file is key. Without such a configuration, **SOAP Importer Helper** will not work. 

The information in necessary to target the right importer and perform authentication.

You can download two fully functional importer configuration files from https://confluence.osc.ndr-net.de/display/TS/SOAP+Importer+Helper.


The following example shows the configuration file `config/importer/tagesschau_qa.cfg` for the SOAP importer.
For secrecy's sake real username and password have been replaced by placeholders *IMPORTER_USER* and *IMPORTER_PASSWORD* :

```
# Sophora importer configuration
IMPORTER_CFG_URL="http://someserver.de:86402/relative_url_to_importer
IMPORTER_CFG_SERVER="someserver.de"
IMPORTER_CFG_USERNAME="IMPORTER_USER"
IMPORTER_CFG_PASSWORD="IMPORTER_PASSWORD"
```

You can copy the default configuration `sample.CMS_ENVIRONMENT.cfg` to something like `unified_dev.cfg`.
Next, you have to fill in the right values on the right side of the equal sign.

(!) **The default configuration is not operative.**<br />
It is just a starting point for your own configuration.





#### curl configuration files

A **curl configuration** file is written in order to run curl with a minimum of parameters on the command line.
This eliminates all kinds of problems that origin from masking quotes and the like on different hosts and shells.

The command
`curl -v --netrc-file /Users/ts/soap_importer_helper/config/importer/tagesschau_qa.cfg -H "Content-Type: text/xml" --data-binary @/Users/ts/soap_importer_helper/sessions/ts_import_test/2022-06-13_084237/soap_envelope.xml IMPORTER-URL`
becomes 
`curl --config /Users/ts/soap_importer_helper/sessions/ts_import_test/2022-06-13_114452/curl_config.cfg`




#### curl netrc configuration files

A **netrc configuration** file is written to provide curl with credentials. This prevents credentials in the command line history. 

- Information in `config/importer/<CMS>_<ENVIRONMENT>.cfg` will be used to automatically create `.netrc` file `config/importer/curl/<CMS>_<ENVIRONMENT>.netrc` (curl needs this information to connect to the importer)

Example: 

```
# Sophora importer configuration to be used by curl
machine some.server.de
login USER_X
password TOP-SECRET
```



#### Directory 'sessions'

The directory `sessions` holds all the data that is produced when running **SOAP Importer Helper**. 

The directory hierarchy is: 

`sessions/CONTEXT/SESSION_IDENTIFIED_BY_TIMESTAMP/` 


The `sessions` (plural) directory holds *session* (singular) directories, which are organized by **CONTEXT** folders.
Each time you run `import.sh` a new session directory is being created.
A session's directory name is a timestamp - the timestamp **SOAP Importer Helper** was run. 

The `sessions` directory might look like this:

```
- sessions
	- <CONTEXT>
		- <TIMESTAMP>
			- nimex_input.xml
			- curl_config.cfg
			- soap_envelope.xml
			- soap_envelope_tmp.xml
			- result.xml
			- run.log
	- radiobremen_test
		- 2022-06-09_125346
			- buten_un_binnen.xml
			- curl_config.cfg
			- soap_envelope.xml
			- soap_envelope_tmp.xml
			- result.xml
			- run.log
	- sportschau_bugfix
		- 2022-06-13_082434
			- beispiel.xml
			- curl_config.cfg
			- soap_envelope.xml
			- soap_envelope_tmp.xml
			- result.xml
			- run.log
		- 2022-06-13_143242
			- beispiel.xml
			- curl_config.cfg
			- soap_envelope.xml
			- soap_envelope_tmp.xml
			- result.xml
			- run.log
		- ...
```


#### Files in a session directory 

A sessions directory contains all files that where used during import (except curls `.netrc` file).

**`nimex_input.xml`**

The NIMEX_SOURCE as specified on the command line. 
On runtime, the NIMEX_SOURCE is copied to the session dir - no matter if NIMEX_SOURCE is a file or a URL. 



**`curl_config.cfg`**

A configuration specific to a context and a session. 
Could be used to examine problems after **SOAP Importer Helper** was run.


**`soap_envelope.xml`**

This is the XML that was sent to SOAP importer. 
It consists of the SOAP_ENVELOPE_HEADER, NIMEX_INPUT and SOAP_ENVELOPE_FOOTER.

When placeholders are being used in the NIMEX source, `soap_envelope.xml` will contain the replacements instead.

- SOAP_ENVELOPE_HEADER is taken from `config/context/CONTEXT/templates/soap_envelope/header.xml`
- SOAP_ENVELOPE_FOOTER is taken from `config/context/CONTEXT/templates/soap_envelope/footer.xml`


**`soap_envelope_tmp.xml`**

Temporary file.<br /> 
Gets deleted unless `DEBUG="true"` is set in `import.sh`.



**`result.xml`**

Answer from SOAP importer.



**`run.log`**

Some information gathered during runtime of **SOAP Importer Helper**.





## Contexts

Use contexts to distinguish different test cases for one and the same combination of CMS and ENVIRONMENT.

**Example no. 1:**

`$ ./import.sh sportschau_test.xml bugfixing sportschau qa`

Here *bugfixing* is the context.



**Example no. 2:**

`$ ./import.sh sportschau_test.xml feature-x sportschau qa`

Here *feature-x* is the context.



A context must not contain spaces. 
To avoid weird problems do not use fancy characters ...





## Replacement of placeholders

When using the **Sophora Deskclient** sometimes it's hard to tell, what imported version you look at. 
To be able to tell the difference easily you can use placeholders with the NIMEX source.
That is, you insert certain placeholders into the NIMEX (e. g. in the *title* tag) and these placeholders will be replaced by a timestamp. 
When reloading the document in the desklient the documents title (headline) is immediately visible and you now when the document you are looking at was imported.

Available placeholders:

- PLACEHOLDER-TIMESTAMP-TIME -> "10:26 Uhr"
- PLACEHOLDER-TIMESTAMP-DATE-AND-TIME -> "13.06.2022 10:26 Uhr"





## Directory layout

```	
- config
	- context
		- <CONTEXT>
			- about.md            (----> ultra short description what this context was set up for)
			- config.cfg          (----> context specific configuration)
			- templates
				- soap_envelope
					- header.xml  (----> context specific XML header)
					- footer.xml  (----> context specific XML footer)
		- sportschau_bugfix
			- about.md
			- config.cfg
			- templates
				- soap_envelope
					- header.xml
					- footer.xml
		- radiobremen_test.cfg
			- about.md
			- config.cfg
			- templates
				- soap_envelope
					- header.xml
					- footer.xml
		- tagesschau_feature_x
			- ...
		- tagesschau_feature_y.cfg
			- ...
	- importer
		- <CMS>_<ENVIRONMENT>.cfg  (---> configuration specific for each combination of <CMS> and <ENVIRONMENT>)
		- tagesschau_dev.cfg       (---> configuration specific for CMS *tagesschau* and ENVIRONMENT *dev*)
		- tagesschau_qa.cfg        (---> configuration specific for CMS *tagesschau* and ENVIRONMENT *qa*)
		- tagesschu_prod.cfg
		- unified_dev.cfg
		- unified_prod.cfg
		- unified_qa.cfg
		- ...
		- curl
			- tagesschau_dev.netrc.cfg  (---> is created automatically based on config/importer/tagesschau_dev.cfg)
			- tagesschau_qa.netrc.cfg   (---> is created automatically based on config/importer/tagesschau_qa.cfg)
			- tagesschu_prod.netrc.cfg  (---> is created automatically based on config/importer/tagesschu_prod.cfg)
			- unified_dev.netrc.cfg     (---> is created automatically based on config/importer/unified_dev.cfg)
			- unified_prod.netrc.cfg    (---> is created automatically based on config/importer/unified_prod.cfg)
			- unified_qa.netrc.cfg      (---> is created automatically based on config/importer/unified_qa.cfg)
			- ...
- sessions
	- <CONTEXT>
		- <TIMESTAMP>
			- nimex_input.xml        (---> NIMEX_SOURCE as specified on the command line)
			- curl_config.cfg        (---> context and session specific)
			- soap_envelope.xml      (---> to be sent to SOAP importer)
			- soap_envelope_tmp.xml  (---> temporary file. Gets deleted unless DEBUG=true)
			- result.xml             (---> answer from SOAP importer)
			- run.log                (---> some log info)
	- radiobremen_test
		- 2022-06-09_125346
			- buten_un_binnen.xml
			- curl_config.cfg
			- soap_envelope.xml
			- soap_envelope_tmp.xml
			- result.xml
			- run.log
	- sportschau_bugfix
		- 2022-06-13_082434
			- beispiel.xml
			- curl_config.cfg
			- soap_envelope.xml
			- soap_envelope_tmp.xml
			- result.xml
			- run.log
		- 2022-06-13_143242
			- beispiel.xml
			- curl_config.cfg
			- soap_envelope.xml
			- soap_envelope_tmp.xml
			- result.xml
			- run.log
		- ...
set_vpn_proxy.sh   (---> sets environment variables for VPN proxy)
```





## Troubleshooting

### Debug mode

If things don't go as expected, you can turn on **debug mode**.

Just place 

`DEBUG="true"`

within `import.sh`.

(Make sure it's not followed by `DEBUG="false"` later on in the code.)


Debug mode ...

- writes more information to STDOUT,
- writes more lines to `run.log` (within each session directory),
- executes curl verbosely and
- prevents temporary files from being deleted.



### Proxy trouble

**Problem**

- NIMEX source is a URL and it can't be downloaded.
- Importer can't be reached. 


**Solution**

**SOAP Importer Helper** assumes VPN connection. 

If you are not using a VPN change the following line in `import.sh`<br/>
from<br/>
`${SCRIPT_PATH}/config/set_vpn_proxy.sh`<br/>
to<br/>
`#${SCRIPT_PATH}/config/set_vpn_proxy.sh`




### Placeholders not replaced

**Problem**

When placeholders are not being replaced at all or sed error show up. 


**Solution**

The command **sed**  is set up to be used on OS X hosts.

If running on linux, adjust<br />
`-i '' ... FILENAME`<br />
to<br />
`-i FILENAME`. 




//==============================================================================
//
//     main.cpp
//
//============================================================================
//  Copyright (C) Guilaume Plante 2020 <cybercastor@icloud.com>
//==============================================================================



#include "stdafx.h"
#include "cmdline.h"
#include "Shlwapi.h"
#include "log.h"

#include <codecvt>
#include <locale>
#include <vector>
#include <unordered_map>
#include <iterator>
#include <regex>
#include <filesystem>
#include <iostream>
#include <sstream>


using namespace std;

#pragma message( "Compiling " __FILE__ )
#pragma message( "Last modified on " __TIMESTAMP__ )

void banner();
void usage();

int main(int argc, TCHAR** argv, TCHAR envp)
{

#ifdef UNICODE
	const char** argn = (const char**)C::Convert::allocate_argn(argc, argv);
#else
	char** argn = argv;
#endif // UNICODE

	CmdLineUtil::getInstance()->initializeCmdlineParser(argc, argn);

	CmdlineParser* inputParser = CmdLineUtil::getInstance()->getInputParser();

	CmdlineOption cmdlineOptionHelp({ "-h", "--help" }, "display this help");
	CmdlineOption cmdlineOptionVerbose({ "-v", "--verbose" }, "verbose output");
	CmdlineOption cmdlineOptionPath({ "-p", "--path" }, "path");
	CmdlineOption cmdlineOptionNoBanner({ "-n", "--nobanner" }, "no banner");
	CmdlineOption cmdlineOptionWhatIf({ "-w", "--whatif" }, "whatif");

	inputParser->addOption(cmdlineOptionHelp);
	inputParser->addOption(cmdlineOptionVerbose);
	
	inputParser->addOption(cmdlineOptionNoBanner); 
	inputParser->addOption(cmdlineOptionWhatIf); 
	inputParser->addOption(cmdlineOptionPath); 


	bool optHelp = inputParser->isSet(cmdlineOptionHelp);
	bool optVerbose = inputParser->isSet(cmdlineOptionVerbose);
	bool optPath= inputParser->isSet(cmdlineOptionPath);
	bool optNoBanner = inputParser->isSet(cmdlineOptionNoBanner);
	bool optWhatIf = inputParser->isSet(cmdlineOptionWhatIf);
	if(optNoBanner == false){
		banner();
	}
	if(optHelp){
		usage();
		return 0;
	}

	COUTC("===============================================");
	COUTC("               TEST APPLICATION                ");
	COUTC("===============================================");


	return 0;
}


void banner() {
	std::wcout << std::endl;
	COUTC("ContainerTester v2.1 - TOOL TO GET FOSSHUB FILES\n");
	COUTC("Built on %s\n", __TIMESTAMP__);
	COUTC("Copyright (C) 2000-2021 Guillaume Plante\n");
	std::wcout << std::endl;
}
void usage() {
	COUTCS("Usage: ctest [-h][-v][-n][-p] path \n");
	COUTCS("   -v          Verbose mode\n");
	COUTCS("   -h          Help\n");
	COUTCSNR("   -w          WhatIf: no actions, get url, test connection.");
	COUTY("  No downloads");
	COUTCS("   -n          No banner\n");
	COUTCS("   -p path     Destination path\n");
	std::wcout << std::endl;
}



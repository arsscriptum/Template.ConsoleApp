
//==============================================================================
//
//     main.cpp
//
//============================================================================
//  Copyright (C) Guilaume Plante 2020 <cybercastor@icloud.com>
//==============================================================================



#include "stdafx.h"
#include "win32.h"
#include "cmdline.h"
#include "Shlwapi.h"
#include "log.h"
#include "httplib.h"
#include "jsmn.h"
#include <codecvt>
#include <locale>
#include <vector>
#include <unordered_map>
#include <iterator>
#include <regex>
#include <filesystem>
#include <iostream>
#include <sstream>

#ifdef USING_HTTPLIB
#pragma message( "USING HTTPLIB" )
#endif

using namespace httplib;
using namespace std;

#pragma message( "Compiling " __FILE__ )
#pragma message( "Last modified on " __TIMESTAMP__ )

void banner();
void usage();
void logError(const char * msg);
char* parseJson(const char* js, int len);
vector<string> split(const string& s, char delim);
static int jsoneq(const char* json, jsmntok_t* tok, const char* s);
string dump_headers(const Headers& headers);
string dump_params(const Params& params);
bool downloadFile(string dwl_url, string fullUrl, string outFile, bool optVerbose);
char* getDlUrl(string filename, string api_url, bool optVerbose);
string log(const Request& req, const Response& res);
void writeFileBytes(const char* filename, const char* buffer, int size);
bool testConnection(const char * host, int port, time_t conn_timeout_sec = 5, time_t read_timeout_sec = 5, time_t write_timeout_sec = 5);


void testLogFunctions(const char * msg);

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
	string destinationPath = ".";
	if (optPath) {
		destinationPath = inputParser->getCmdOption("-p");
	}


	testLogFunctions(destinationPath.c_str());
	return 0;
  
	auto my_url = "https://arsscriptum.github.io";
	auto api_url = "https://api.fosshub.com";	
	auto dwl_url = "https://download.fosshub.com";	
	
  	auto filename = "iview460_x64_setup.exe"; 
    auto release_id = "623457812413750bd71fef36";    
    auto project_id = "5b8d1f5659eee027c3d7883a";
	
	string dest = destinationPath + "\\" + filename;

	bool strApiConnected = testConnection("api.fosshub.com",443);
	COUTMM("testConnection on %s --> ", "api.fosshub.com");
	COUTY("%s", strApiConnected?"CONNECTION SUCCESS":"CONNECTION FAILED");

	if (!strApiConnected){
		logError("Server unreachable. Exiting...");
		return -1;
	}
 
	COUTMM("testConnection on %s --> ", "download.fosshub.com");
	bool strDownloadConnected = testConnection("download.fosshub.com",443);
	COUTY("%s", strDownloadConnected?"CONNECTION SUCCESS":"CONNECTION FAILED");
	if (!strDownloadConnected){
		logError("Server unreachable. Exiting...");
		return -1;
	}
 
	// ==================================================================
	// GET iview460_x64_setup.exe
	// ==================================================================
	char *fullUrl = getDlUrl(filename, api_url, optVerbose);
	if (optWhatIf) {
		COUTRS("WhatIf: No Download. %s\n", fullUrl);
		return 0;
	}
	if (fullUrl) {
		bool downloaded = downloadFile(dwl_url, fullUrl, dest, optVerbose);
		if (!downloaded){
			logError("Download failed. Exit...");
			return -1;
		}
	}

	// ==================================================================
	// GET iview460_plugins_x64_setup.exe
	// ==================================================================
	filename = "iview460_plugins_x64_setup.exe";
	dest = destinationPath + "\\" + filename;
	fullUrl = getDlUrl(filename, api_url, optVerbose);
	if (optWhatIf) {
		COUTRS("WhatIf: No Download. %s\n", fullUrl);
		return 0;
	}
	
	if (fullUrl) {
		bool downloaded = downloadFile(dwl_url, fullUrl, dest, optVerbose);
		if (!downloaded){
			logError("Download failed. Exit...");
			return -2;
		}
	}

	return 0;
}

char* parseJson(const char *js, int len){

	int i;
	int r;
	jsmn_parser p;
	jsmntok_t t[128]; /* We expect no more than 128 tokens */

	jsmn_init(&p);
	r = jsmn_parse(&p, js, len, t, sizeof(t) / sizeof(t[0]));
	if (r < 0) {
	    COUTRS("Failed to parse JSON: %d\n", r);
	    return nullptr;
	}

	std::string url_res = "";
  	for (i = 1; i < r; i++) {
    	if (jsoneq(js, &t[i], "url") == 0) {
    	  
    	  char *str = (char*)malloc(512);
	      /* We may use strndup() to fetch string value */
	      sprintf(str, "%.*s", t[i + 1].end - t[i + 1].start, js + t[i + 1].start);
	      i++;
	      
	      return str;
	    }
  	}
  return nullptr;
}



vector<string> split(const string& s, char delim) {
	vector<string> result;
	stringstream ss(s);
	string item;

	while (getline(ss, item, delim)) {
		result.push_back(item);
	}

	return result;
}


static int jsoneq(const char* json, jsmntok_t* tok, const char* s) {
	if (tok->type == JSMN_STRING && (int)strlen(s) == tok->end - tok->start &&
		strncmp(json + tok->start, s, tok->end - tok->start) == 0) {
		return 0;
	}
	return -1;
}


string dump_headers(const Headers& headers) {
	string s;
	char buf[BUFSIZ];

	for (const auto& x : headers) {
		snprintf(buf, sizeof(buf), "%s: %s\n", x.first.c_str(), x.second.c_str());
		s += buf;
	}

	return s;
}

string dump_params(const Params& params) {
	string s;
	char buf[BUFSIZ];

	for (const auto& x : params) {
		snprintf(buf, sizeof(buf), "%s: %s\n", x.first.c_str(), x.second.c_str());
		s += buf;
	}

	return s;
}


void banner() {
	std::wcout << std::endl;
	COUTC("getfh v2.1 - TOOL TO GET FOSSHUB FILES\n");
	COUTC("Built on %s\n", __TIMESTAMP__);
	COUTC("Copyright (C) 2000-2021 Guillaume Plante\n");
	std::wcout << std::endl;
}
void usage() {
	COUTCS("Usage: getfh.exe [-h][-v][-n][-p] path \n");
	COUTCS("   -v          Verbose mode\n");
	COUTCS("   -h          Help\n");
	COUTCSNR("   -w          WhatIf: no actions, get url, test connection.");
	COUTY("  No downloads");
	COUTCS("   -n          No banner\n");
	COUTCS("   -p path     Destination path\n");
	std::wcout << std::endl;
}



void writeFileBytes(const char* filename, const char* buffer, int size) {
	COUTRS("Saving file %s.\n", filename);
	std::ofstream outfile(filename, std::ios::out | std::ios::binary);
	// write to outfile
	outfile.write(buffer, size);

	outfile.close();
}

string log(const Request& req, const Response& res) {
	string s;
	char buf[BUFSIZ];

	s += "================================\n";

	snprintf(buf, sizeof(buf), "%s %s %s", req.method.c_str(),
		req.version.c_str(), req.path.c_str());
	s += buf;

	string query;
	for (auto it = req.params.begin(); it != req.params.end(); ++it) {
		const auto& x = *it;
		snprintf(buf, sizeof(buf), "%c%s=%s",
			(it == req.params.begin()) ? '?' : '&', x.first.c_str(),
			x.second.c_str());
		query += buf;
	}
	snprintf(buf, sizeof(buf), "%s\n", query.c_str());
	s += buf;

	s += dump_headers(req.headers);


	s += "--------------------------------\n";

	snprintf(buf, sizeof(buf), "%d\n", res.status);
	s += buf;
	s += dump_headers(res.headers);

	return s;
}

char* getDlUrl(string filename, string api_url, bool optVerbose) {

	COUTYS("Retrieving Download URL for \"%s\"", filename.c_str());
	httplib::Params params;
	params.emplace("projectUri", "IrfanView.html");
	params.emplace("fileName", filename);
	params.emplace("releaseId", "623457812413750bd71fef36");
	params.emplace("projectId", "5b8d1f5659eee027c3d7883a");
	params.emplace("source", "CF");

	if (optVerbose) {
		string strParams = dump_params(params);
		COUTMS("=== Request Parameters ===");
		COUTM("%s", strParams.c_str());
	}
	httplib::Client cli(api_url);
	cli.set_connection_timeout(5,0);
	cli.set_read_timeout(5,0);
	cli.set_keep_alive(true);
	auto res = cli.Post("/download", params);

	if (res->status != 200) {
		COUTRS("Error %d.\n", res->status);
		return nullptr;
	}

	std::string body = res->body;

	const char* chr = body.c_str();
	int len = body.size();
	char* download_url = parseJson(chr, len);

	if (optVerbose) {
		COUTYRL("Download URL: ");
		COUTRS("\"%s\"", download_url);
	}
	return download_url;
}

bool downloadFile(string dwl_url, string fullUrl, string outFile, bool optVerbose) {

	bool result = false;
	vector<string> v = split(fullUrl, '/');
	char* str = (char*)malloc(512);
	strcpy(str, "/");
	for (int i = 3; i < v.size(); i++) {
		strcat(str, v[i].c_str());
		if (i < (v.size() - 1)) { strcat(str, "/"); }
	}
	try {
		httplib::Headers h;

		h.emplace("sec-ch-ua", "\" Not A;Brand\";v=\"99\", \"Chromium\";v=\"99\", \"Google Chrome\";v=\"99\"");
		h.emplace("sec-ch-ua-mobile", "?0");
		h.emplace("sec-ch-ua-platform", "Windows");
		h.emplace("Upgrade-Insecure-Requests", "1");
		h.emplace("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.51 Safari/537.36");
		h.emplace("Sec-Fetch-Site", "same-site");
		h.emplace("Sec-Fetch-Mode", "navigate");
		h.emplace("Sec-Fetch-Dest", "document");
		h.emplace("Referer", "https=//www.fosshub.com/");
		h.emplace("Accept-Encoding", "gzip, deflate, br");

		COUTYS("Requesting File to server %s.\nRequest: %s", dwl_url.c_str(), str);

		if (optVerbose) {
			string strHeaders = dump_headers(h);
			COUTMS("=== Request Headers ===");
			COUTM("%s", strHeaders.c_str());
		}

		string rcvdata;

		httplib::Client cli(dwl_url);
		if (optVerbose) {
			cli.set_logger(
				[](const Request& req, const Response& res) {
					string l = log(req, res);
					COUTM("%s", l.c_str());
				});
		}
		cli.set_connection_timeout(5,0);
		cli.set_read_timeout(5,0);
		cli.set_keep_alive(true);
		auto getres = cli.Get(str, h,
			[&](const char* data, size_t data_length) {
				rcvdata.append(data, data_length);
				if (optVerbose) {
					COUTRS("Received %d bytes. Total: %d", data_length, rcvdata.size());
				}
				return true;
			}
			//,[&](uint64_t offset, uint64_t total_length) { COUTMS("received %d/%s", offset, total_length); return true; }
		);
		if (getres->status == 200) {
			writeFileBytes(outFile.c_str(), rcvdata.data(), rcvdata.length());
			result = true;
		}

	}
	catch (...) { COUTRS("Caught Error.\n"); result = false; }
	return result;
}

void testLogFunctions(const char * msg){
	COUTTITLE("TITLE MESSAGE\n");


	COUTINFO("VERY IMPORTANT INFORMATION\n");
	
}




void logError(const char * msg){
	COUTMM("[ERROR] ");
	COUTY("%s", msg);
}


// Sends a raw request to a server listening at HOST:PORT.
bool testConnection(const char * host, int port, time_t conn_timeout_sec, time_t read_timeout_sec, time_t write_timeout_sec) {
  auto error = Error::Success;

  auto client_sock = detail::create_client_socket(
      host, "", port, AF_UNSPEC, false, nullptr,
      conn_timeout_sec, 0,
      read_timeout_sec, 0,
      write_timeout_sec, 0, std::string(), error);

  if (client_sock == INVALID_SOCKET) { return false; }

  detail::close_socket(client_sock);

  return true;
}

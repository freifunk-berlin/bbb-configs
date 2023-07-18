#!/usr/bin/python3

import argparse
import os
import re

import requests
from dotenv import load_dotenv

"""
This script was derived from the edit_section.py script from the
freifunk-berlin repo https://github.com/freifunk-berlin/falter-wiki-bot.
"""

############
#  CONFIG  #
############

if not load_dotenv(".env"):
    raise FileNotFoundError(
        (
            "No .env file found. Please make shure you used example.env as a template"
            "and filled in your personal credentials."
        )
    )

API_URL = "https://wiki.freifunk.net/api.php"
WIKI_URL = "https://wiki.freifunk.net"
INTRO = (
    "<b>Diesen Abschnitt nicht bearbeiten. Änderungen werden automatisch überschrieben!</b>"
    "<br> Die Konfiguration für diesen Standort wurde mit dem Tool"
    "[https://github.com/freifunk-berlin/bbb-configs bbb-configs] erstellt."
    "Der aktuelle Stand der Konfiguration kann dort eingesehen werden."
    "Teile des Wikiartikels werden mit Hilfe von Semantic Values und Templates automatisch erstellt."
)

# (Sub)-String that marks a auto-generated bbb-configs section
SECTION_REGEX = "Konfiguration"
s = requests.Session()

################
#  FUNCTIOINS  #
################


def find_wiki_page(node: str):
    query = (
        f"{API_URL}?action=ask&query=[[Hat_Knoten%3A%3A{node}]]"
        "|%3FModification date|sort%3DModification date|order%3Ddesc&format=json"
    )
    response = s.get(url=query).json()
    print(response)
    results = response.get("query").get("results")

    if len(results) == 0:
        raise ValueError(f"No Wiki article found for the given node name: {node}")
        exit(1)

    return list(results.values())[0].get("fulltext")


# queries the article and looks for the number of the section
# containing the auto-generated configuration
def find_bbbconfigs_section(pagetitle: str):
    params = {"action": "parse", "page": pagetitle, "format": "json"}
    response = s.get(url=API_URL, params=params).json()

    sections = response.get("parse").get("sections")

    # iterate over sections and find bbb-config section
    bbb_configs_section = -1
    bbb_configs_section_title = ""
    for sec in sections:
        sec_title = sec.get("line")
        if re.search(SECTION_REGEX, sec_title):
            bbb_configs_section = sec["index"]
            bbb_configs_section_title = sec_title
            break

    if bbb_configs_section != -1:
        return {"index": bbb_configs_section, "title": bbb_configs_section_title}
    else:
        raise ValueError(
            (
                "Theres no Konfiguration-section in the given article! See instructions at"
                "https://github.com/freifunk-berlin/bbb-configs#automaticly-updating-to-wikifreifunknet"
            )
        )


def get_login_token():
    # Get login token for API calls
    param_login_query = {
        "action": "query",
        "meta": "tokens",
        "type": "login",
        "format": "json",
    }

    r = s.get(url=API_URL, params=param_login_query)
    data = r.json()
    return data["query"]["tokens"]["logintoken"]


def login_at_api(login_token):
    # Send a post request to login.
    params_login = {
        "action": "login",
        "lgname": os.getenv("FF_WIKI_USER"),
        "lgpassword": os.getenv("FF_WIKI_PASSWORD"),
        "lgtoken": login_token,
        "format": "json",
    }

    s.get(url=API_URL, params=params_login)


def fetch_csrf_token():
    # GET request to fetch CSRF token
    params_csrf = {"action": "query", "meta": "tokens", "format": "json"}

    r = s.get(url=API_URL, params=params_csrf)
    data = r.json()

    return data["query"]["tokens"]["csrftoken"]


def edit_section(article_title, section_number, csrf_token, new_text):
    # POST request to edit specific section in a page
    params_edit = {
        "action": "edit",
        "title": article_title,
        "section": section_number,  # 0=Introduction, 1=first_section, etc.
        "token": csrf_token,
        "bot": True,
        # "minor": True,
        "format": "json",
        "text": new_text,
        "summary": "Automatisches Update aus bbb-configs.",
    }

    r = s.post(API_URL, data=params_edit)
    data = r.json()

    if data.get("error"):
        raise ValueError(data.get("error").get("info"))
        exit(1)
    if data.get("edit").get("nochange") == "":
        print(
            (
                "SKIPPED: The Wiki article was already up to date."
                "No changes were made. See: {WIKI_URL}/{data.get('edit').get('title')}"
            )
        )
    else:
        print(
            (
                "UPDATED: The wiki article was successfully updated."
                "Check the results at: {WIKI_URL}/{data.get('edit').get('title')}"
            )
        )


if __name__ == "__main__":
    #####################
    #  ARGUMENT PARSER  #
    #####################

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-n", "--node", help="node whose wiki article should be edited.", required=True
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--text", help="String which should be posted into section.")
    group.add_argument("-f", "--file", help="Read text from a file")
    args = parser.parse_args()

    ########################
    #  Paste text to Wiki  #
    ########################

    pagetitle = find_wiki_page(args.node)
    section = find_bbbconfigs_section(pagetitle)

    pagetxt = f"== {section['title']} ==\n\n"  # Text that gets posted into the specific article section
    pagetxt += f"{INTRO}\n\n"

    if args.text:
        pagetxt += args.text
    else:
        pagetxt += open(args.file, "r").read()

    login_token = get_login_token()
    login_at_api(login_token)
    csrf_token = fetch_csrf_token()

    edit_section(pagetitle, section["index"], csrf_token, pagetxt)

    s.close()

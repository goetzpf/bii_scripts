# -*- coding: utf-8 -*-

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Bernhard Kuner <bernhard.kuner@helmholtz-berlin.de>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

""" A Tokenizer: 

The Tokens are processed in the defined order.

*  Token definition  : a list of regexp containing one or three elements:

- One element: The regexp to recognize the token
- Three elements: Token begin , Token content, Token delimiter

Token definition Example:

     tokDefList =( ('B_OPEN', (r'\(',) ),\
		  ('B_CLOSE',	  (r'\)',) ),\
		  ('COMMA',	      (r',',) ),\
		  ('QSTRING',(r'(?<!\\)"(.*?)(?<!\\)"',) ), \
		  ('WORD',	      (r'[a-zA-Z0-9_/\.:=\-\{\}\$]+',) ),\
		  ('COMMENT',	      (r'#.*',) ),\
		  ('SPACE',(r"\s+",))
		 )

*  Return:  a list of tokens
"""
import sys
import pprint
import re

assert sys.version_info[0]==2

def compileTokDefList(tokDefList):
    """ Compile and return the token definitions
	Raise 'ValueError' for illegal definitions
    """
    tokReList = []  #compiled regexp: ['TOKENNAME,[reBegin,reToken,reDelim]] or ['TOKENNAME,[reToken]]
    for (tokName,tokRe) in tokDefList:
#    	tokReList.append([tokName,map(lambda x: re.compile(x),tokRe)])
    	tt= []
	for t in tokRe:
	    try:
	    	tt.append(re.compile(t))
	    except re.error,e:
	    	raise ValueError( "'"+str(e)+"' in compile "+tokName+", '"+t+"'")
	tokReList.append([tokName,tt])
    return tokReList
        
def parse(parse,tokReList,line):
    """ Parse a line to the compiled token definition list. 
    	Return the token list [('TOKNAME','TOKVAL'),...] (including all space tokens etc.)
	Raise 'ValueError' for unreadable lines
    """
    def matchToken(parse,parsePos,tokName,tokRe):
	result = tokRe.match(parse,parsePos)
	if result:
    	    #print "\tmatchToken: '"+tokName+"'='"+result.group()+"'",result.start(),result.end(),"parse ='"+parse+"'"
	    g = result.groups()
	    if len(g)==0:
	    	g=result.group()
	    else:
    		g = g[0]

	    return (result.end(),g)    # match: next pos + content
	return (parsePos,None)    	    	     # didn't match: old pos, no content
    tokList = []
    parsePos=0
    while 1:
	parseNext = parsePos
	for (tokName, tokRe) in tokReList:
	    #print parsePos,"Test:",tokName
	    if len(tokRe) == 1:     # is a single RE token
	    	(parseNext,tokContent) = matchToken(parse,parsePos,tokName,tokRe[0])
    	    	#print "\tTest-1 ("+str(parseNext)+",'"+str(tokContent)+"' parse next: '"+parse[parseNext:]+"'"
		if tokContent is not None:
		    tokList.append((tokName,tokContent))
		    break
		elif parseNext > parsePos:	# next if ignored tokName e.g. 'FORGETT_SPACE_CHARACTERS'
		    break
	    elif len(tokRe) == 3:   # is a three RE token block
	    	(parseNext,tokBegin) = matchToken(parse,parsePos,tokName,tokRe[0])
    	    	#print "\tTest-3 begin ("+str(parseNext)+",'"+str(tokContent)+"' parse next: '"+parse[parseNext:]+"'"
		if tokBegin:
	    	    (parseNext,tok) = matchToken(parse,parseNext,tokName,tokRe[1])
    	    	    #print "\tTest-3 match ("+str(parseNext)+",'"+str(tok)+"' parse next: '"+parse[parseNext:]+"'"
		    if tok:
	    	    	(parseNext,tokContent) = matchToken(parse,parseNext,tokName,tokRe[2])
		    	#print "\tTest-3 end ("+str(parseNext)+",'"+str(tokContent)+"' parse next: '"+parse[parseNext:]+"'"
			if tokContent:
			    tokList.append((tokName,tok))
		    	    break
			else:
			    raise ValueError("Line "+str(line)+": Can't find token delimiter for tokContent***parse")
		    else:
			raise ValueError("Line "+str(line)+": Can't find token Content for parse")
	    else:
		raise ValueError("Can't find token Content for parse")
    	if parsePos < len(parse):
	    if parseNext == parsePos:   # tokReList done, but no new position - means no match 
	    	raise ValueError("Line "+str(line)+": Illegal token in: '"+parse[0:parsePos]+"***'"+parse[parsePos:]+"'***'")
	    else:
		parsePos = parseNext    # found new position
	else:   	    	    	    # end reached: break while
	    break
    #pprint.pprint(tokList)
    return tokList

def getNextToken(tokList,skip=('SPACE',)):
    """ return the next token (tokName,tokValue) that is not in skip list.
    	skip SPACE is default, SPACE has to be defined in the toList!!
    	or (None,None) if tokList is done.
    """
    while tokList:
    	(tName,tVal) = tokList.pop(0)
	#print "getNextToken:",tName,tVal
	if tName not in skip:
	    return (tName,tVal)
    return (None,None)
	    
def parseStCmd(stCmdLine,tokenList,lineNr=None):
    """parse one line of a st.cmd file. 
       Return list of tokenvalues of tokentypes in ('QSTRING','WORD')
    """
    data = []
    tokList = parse(stCmdLine,tokenList,lineNr)
    (tName,tVal) = getNextToken(tokList,('LOAD','COMMENT','SPACE'))
    if not tName:
    	return
    if tName in ('QSTRING','WORD') :
    	data.append(tVal)
    	while tokList:
	    (tName,tVal) = getNextToken(tokList,('COMMENT','SPACE'))
	    if tName  in ('QSTRING','WORD'):
	    	#print "parseStCmd",lineNr, tName,tVal
		data.append(tVal)
    else:
	raise ValueError("Line begin with ilegal token: "+str(tName)+", '"+str(tVal)+"' in Line "+str(lineNr))
	
    return data

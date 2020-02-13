program wrappermaker;

//**********************************************************************************************************************************
//
//  Pascal interface generator for TensorFlow operations
//
//  Copyright: (C) 2020, Zsolt Szakaly
//
//  This source is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as
//  published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
//
//  This code is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
//
//  A copy of the GNU General Public License is available on the World Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can
//  also obtain it by writing to the Free Software Foundation, Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1335, USA.
//
//  Change log: 13/02/2020 Initial version
//
//**********************************************************************************************************************************
//
//  Description
//
//  This program is really Work-In-Progress.
//  This is reading TensorFlow's ops.pbtxt file (available from github.com/tensorflow) and generates from it Pascal interfaces.
//  There are two ways to use them.
//  The classic TensorFlow approach, whereby a Graph is built. The base object for that is TGraph declared in tf_operations.
//  Its most important function is AddOper, what adds a new node or operation to the TensorFlow Graph. The unit that can be
//  generated by this program declares TGraphExt and declares Add<oper> functions for all the operations declared in ops.pbtxt
//  (currently well over 1000).
//  The other approach does not require building of a Graph, but the operations can be called directly with Tensor inputs (defined
//  using tf_tensors). Just like for the Graph approach, there is a General version of ExecOper in tf_operations. The unit generated
//  using this program builts on ExecOper, creating an operation specific Exec<oper> function for (almost) every function.
//  For details how to use this program read its help (help1.txt and help2.txt) or run it with option -h.
//
//**********************************************************************************************************************************

// The global uses
uses
  Sysutils;

// The CommandLine parameter handling variables
var
  // RFU CmdLineC:                    integer=        1; // Comments in the generated unit: 0 - none, 1 - defaults, 3 - details
  // RFU CmdLineD:                    integer=        1; // Default handling: 0 - only full, 1 - full and none, 2 - many combinations,
                                                  //   3 - all with different names
  CmdLineE:                    string=         'Exec'; // The prefix to add before the Ops name in the Eager version
  CmdLineG:                    string=         'Add'; // The prefix to add before the Ops name in the Graph version
  CmdLineH:                    integer=        0; // The help level: 0 - no help, 1 - short (default), 2 - full
  CmdLineO:                    string=         'tf_wrapper.pas'; // The output file name
  CmdLineS:                    string=         'ops.pbtxt'; // The source to use
  CmdLineT:                    string=         'tf_wrappertemplate.pas'; // The template to use
  CmdLineU:                    integer=        3; // Unit generated: 1 - Graph only, 2 - Eager only, 3 - Both
  CmdLineV:                    integer=        1; // Verbose: 0 - nothing, 1 - error and summary, 2 - comments
function ProcessCommandLine:boolean;
  var
    i:integer;
    ParameterProcessed:boolean;
    ParameterID:string;
    ParameterValue:string;
    ParameterCode:integer;
    ErrorCode:integer;
  begin
  result:=false;
  for i:=1 to ParamCount do
    begin
    ParameterProcessed:=false;
    // Preparation
    if Pos('=',ParamStr(i))>0 then
      begin
      ParameterID:=Copy(ParamStr(i),1,Pos('=',ParamStr(i))-1);
      ParameterValue:=Copy(ParamStr(i),Pos('=',ParamStr(i))+1);
      ParameterID:=lowercase(ParameterID);
      end
    else
      begin
      ParameterID:=lowercase(ParamStr(i));
      ParameterValue:='';
      end;
    (*
    // Comments
    if (ParameterID='-c') or
       (ParameterID='--comments') then
      begin
      val(ParameterValue,ParameterCode,ErrorCode);
      if (ErrorCode<>0) or (ParameterCode<0) or (ParameterCode>2) then
        begin
        writeln('Invalid value for '+ParameterID);
        exit;
        end;
      CmdLineC:=ParameterCode;
      ParameterProcessed:=true;
      end;
    *)
    (*
    // Default handling
    if (ParameterID='-d') or
       (ParameterID='--default-handling') then
      begin
      val(ParameterValue,ParameterCode,ErrorCode);
      if (ErrorCode<>0) or (ParameterCode<0) or (ParameterCode>3) then
        begin
        writeln('Invalid value for '+ParameterID);
        exit;
        end;
      CmdLineD:=ParameterCode;
      ParameterProcessed:=true;
      end;
    *)
    // EagerPrefix
    if (ParameterID='-e') or
       (ParameterID='--eager-prefix') then
      begin
      CmdLineE:=ParameterValue;
      if Pos('''',ParameterValue)=1 then
        begin
        if ParameterValue[Length(ParameterValue)]<>'''' then
          begin
          writeln('Misformatted parameter for '+ParameterID);
          exit;
          end;
        CmdLineE:=copy(ParameterValue,2,Length(ParameterValue)-2);
        end;
      if Pos('"',ParameterValue)=1 then
        begin
        if ParameterValue[Length(ParameterValue)]<>'"' then
          begin
          writeln('Misformatted parameter for '+ParameterID);
          exit;
          end;
        CmdLineE:=copy(ParameterValue,2,Length(ParameterValue)-2);
        end;
      ParameterProcessed:=true;
      end;
    // GraphPrefix
    if (ParameterID='-g') or
       (ParameterID='--graph-prefix') then
      begin
      CmdLineG:=ParameterValue;
      if Pos('''',ParameterValue)=1 then
        begin
        if ParameterValue[Length(ParameterValue)]<>'''' then
          begin
          writeln('Misformatted parameter for '+ParameterID);
          exit;
          end;
        CmdLineG:=copy(ParameterValue,2,Length(ParameterValue)-2);
        end;
      if Pos('"',ParameterValue)=1 then
        begin
        if ParameterValue[Length(ParameterValue)]<>'"' then
          begin
          writeln('Misformatted parameter for '+ParameterID);
          exit;
          end;
        CmdLineG:=copy(ParameterValue,2,Length(ParameterValue)-2);
        end;
      ParameterProcessed:=true;
      end;
    // Help
    if (ParameterID='?') or
       (ParameterID='-h') or
       (ParameterID='--help') then
      begin
      if ParameterValue='' then
        ParameterValue:='1'; // The default help value for unspecified help
      val(ParameterValue,ParameterCode,ErrorCode);
      if (ErrorCode<>0) or (ParameterCode<1) or (ParameterCode>2) then
        begin
        writeln('Invalid value for '+ParameterID);
        exit;
        end;
      CmdLineH:=ParameterCode;
      ParameterProcessed:=true;
      end;
    // OutputFile
    if (ParameterID='-o') or
       (ParameterID='--output-file') then
      begin
      CmdLineO:=ParameterValue;
      if Pos('''',ParameterValue)=1 then
        begin
        if ParameterValue[Length(ParameterValue)]<>'''' then
          begin
          writeln('Misformatted parameter for '+ParameterID);
          exit;
          end;
        CmdLineO:=copy(ParameterValue,2,Length(ParameterValue)-2);
        end;
      if Pos('"',ParameterValue)=1 then
        begin
        if ParameterValue[Length(ParameterValue)]<>'"' then
          begin
          writeln('Misformatted parameter for '+ParameterID);
          exit;
          end;
        CmdLineO:=copy(ParameterValue,2,Length(ParameterValue)-2);
        end;
      ParameterProcessed:=true;
      end;
    // Source
    if (ParameterID='-s') or
       (ParameterID='--source') then
      begin
      CmdLineS:=ParameterValue;
      if Pos('''',ParameterValue)=1 then
        begin
        if ParameterValue[Length(ParameterValue)]<>'''' then
          begin
          writeln('Misformatted parameter for '+ParameterID);
          exit;
          end;
        CmdLineS:=copy(ParameterValue,2,Length(ParameterValue)-2);
        end;
      if Pos('"',ParameterValue)=1 then
        begin
        if ParameterValue[Length(ParameterValue)]<>'"' then
          begin
          writeln('Misformatted parameter for '+ParameterID);
          exit;
          end;
        CmdLineS:=copy(ParameterValue,2,Length(ParameterValue)-2);
        end;
      ParameterProcessed:=true;
      end;
    // Template
    if (ParameterID='-t') or
       (ParameterID='--template') then
      begin
      CmdLineT:=ParameterValue;
      if Pos('''',ParameterValue)=1 then
        begin
        if ParameterValue[Length(ParameterValue)]<>'''' then
          begin
          writeln('Misformatted parameter for '+ParameterID);
          exit;
          end;
        CmdLineT:=copy(ParameterValue,2,Length(ParameterValue)-2);
        end;
      if Pos('"',ParameterValue)=1 then
        begin
        if ParameterValue[Length(ParameterValue)]<>'"' then
          begin
          writeln('Misformatted parameter for '+ParameterID);
          exit;
          end;
        CmdLineT:=copy(ParameterValue,2,Length(ParameterValue)-2);
        end;
      ParameterProcessed:=true;
      end;
    // Unit generated
    if (ParameterID='-u') or
       (ParameterID='--unit') then
      begin
      val(ParameterValue,ParameterCode,ErrorCode);
      if (ErrorCode<>0) or (ParameterCode<1) or (ParameterCode>3) then
        begin
        writeln('Invalid value for '+ParameterID);
        exit;
        end;
      CmdLineU:=ParameterCode;
      ParameterProcessed:=true;
      end;
    // Verbose
    if (ParameterID='-v') or
       (ParameterID='--verbose') then
      begin
      val(ParameterValue,ParameterCode,ErrorCode);
      if (ErrorCode<>0) or (ParameterCode<1) or (ParameterCode>3) then
        begin
        writeln('Invalid value for '+ParameterID);
        exit;
        end;
      CmdLineV:=ParameterCode;
      ParameterProcessed:=true;
      end;
    if not ParameterProcessed then
      begin
      writeln('Unknown parameter: '+ParamStr(i));
      writeln('Use -H for "Help"');
      exit;
      end;
    end;
  result:=true;
  end;

// The help files and their printing
const
  Help1={$i help1.txt};
  Help2={$i help2.txt};
procedure PrintHelp;
  begin
  case CmdLineH of
    1:writeln(Help1);
    2:writeln(Help2);
    end;
  end;

// The load or later the download of the TensorFlow definition file
var OpsPbtxt:                  string;
function LoadOpsPbtxt:boolean;
  var
    OpsPbtxtFile:system.text;
    OneLine:string;
  begin
  result:=false;
  // Read the file into one long string
  AssignFile(OpsPbtxtFile,CmdLineS);
  try
    Reset(OpsPbtxtFile);
  except
    if CmdLineV>=1 then
      writeln('Cannot read Source file '+CmdLineS);
    exit;
    end;
  OpsPbtxt:='';
  while not eof(OpsPbtxtFile) do
    begin
    readln(OpsPbtxtFile,OneLine);
    OpsPbtxt:=OpsPbtxt+OneLine+' '; // to make sure that when two lines are cooncatanated a space is added
    end;
  CloseFile(OpsPbtxtFile);
  result:=true;
  end;
function GetOpsPbtxt:boolean;
  begin
  // Placeholder to potentially Download from GitHub the latest definition file, if CmdLineS is a site, not a file
  // Currently only file load is supported
  { TODO : Add Download option }
  result:=LoadOpsPbtxt;
  end;
function RemoveExtraSpaces:boolean;
  var
    TempStr:                   string;
    Counter:                   Int32;
    I:                         Int32;
    LastSpace:                 boolean;
  begin
  Counter:=0;
  TempStr:=OpsPbtxt; // Manage the output in the memory area of the original OpsPbtxt, and so no frequent memory allocation is needed
  LastSpace:=true;
  for I:=1 to Length(TempStr) do
    if (TempStr[I]<>' ') or (not LastSpace) then
      begin
      inc(Counter);
      OpsPbtxt[Counter]:=TempStr[I];
      LastSpace:=TempStr[I]=' ';
      end;
  SetLength(OpsPbtxt,Counter);
  result:=true;
  end;

// The load of the template for the output
var TemplateStr:                  string;
function LoadTemplate:boolean;
  var
    TemplateFile:system.text;
    OneLine:string;
  begin
  result:=false;
  // Read the file into one long string
  AssignFile(TemplateFile,CmdLineT);
  try
    Reset(TemplateFile);
  except
    if CmdLineV>=1 then
      writeln('Cannot read Template file '+CmdLineT);
    exit;
    end;
  TemplateStr:='';
  while not eof(TemplateFile) do
    begin
    readln(TemplateFile,OneLine);
    TemplateStr:=TemplateStr+OneLine+#$0d#$0a;
    end;
  CloseFile(TemplateFile);
  result:=true;
  end;
function SaveUnit:boolean;
  var
    UnitFile:file;
  begin
  result:=false;
  AssignFile(UnitFile,CmdLineO);
  try
    Rewrite(UnitFile,1);
  except
    exit;
    end;
  BlockWrite(UnitFile,TemplateStr[1],Length(TemplateStr));
  CloseFile(UnitFile);
  result:=true;
end;

// A parser to cut a string into three
procedure ParseStringIntoThree(const AInput:string; var ALabel:string; var AContent:string; var ARest:string);
  var
    SplitPos:                  Int32;
    ParanthesisCount:          Int32;
  begin
  SplitPos:=Pos(' ',AInput);
  ALabel:=Copy(AInput,1,SplitPos-1);
  ARest:=Copy(AInput,SplitPos+1);
  if ARest[1]<>'{' then
    begin
    SplitPos:=Pos(' ',ARest);
    if SplitPos=0 then
      begin
      AContent:=ARest;
      ARest:='';
      end
    else
      begin
      AContent:=Copy(ARest,1,SplitPos-1);
      ARest:=Copy(ARest,SplitPos+1);
      end;
    end
  else
    begin
    SplitPos:=1;
    ParanthesisCount:=1;
    while ParanthesisCount<>0 do
      begin
      inc(SplitPos);
      if ARest[SplitPos]='{' then
        inc(ParanthesisCount)
      else
        if ARest[SplitPos]='}' then
          dec(ParanthesisCount);
      end;
    AContent:=Copy(ARest,3,SplitPos-4);
    ARest:=Copy(ARest,SplitPos+2);
    end;
  end;

// The actual processing of the file
type
  TAttributeInputPair=record
    Attribute:              string;
    Input:                  string;
    end;
function InAttributeInputPair(const AArray:array of TAttributeInputPair; const AAttribute:string):integer;
  var i:integer;
  begin
  result:=-1;
  i:=0;
  while (i<Length(AArray)) and // has not reached the end
        (AArray[i].Attribute<>AAttribute) do
    inc(i);
  if i<Length(AArray) then
    result:=i;
  end;
var
  Inputs:                    array of string;
  InputLists:                array of string;
  Outputs:                   array of string;
  OutputLists:               array of string;
  AttributeNames:            array of string;
  AttributeTypes:            array of string;
  AttributeDefaults:         array of boolean;
  InputTypes:                array of TAttributeInputPair;
procedure ProcessInputArg(var AInput:string);
  var
    LabelString:               string='';
    ContentString:             string='';
    LabelProcessed:            boolean;
    InputName:                 string='';
    InputMultiple:             boolean=false;
  begin
  while AInput<>'' do
    begin
    ParseStringIntoThree(AInput,LabelString,ContentString,AInput);
    LabelProcessed:=false;
    if LabelString='is_ref:' then
      begin
      // no need to processed { TODO : Is it surely not needed }
      LabelProcessed:=true;
      end;
    if LabelString='name:' then
      begin
      LabelProcessed:=true;
      if InputName='' then
        InputName:=Copy(ContentString,2,Length(ContentString)-2)
      else
        begin
        if CmdLineV>=1 then
          writeln('Input has duplicate Name value!');
        end;
      end;
    if LabelString='number_attr:' then
      begin
      LabelProcessed:=true;
      InputMultiple:=true;
      end;
    if LabelString='type:' then
      begin
      LabelProcessed:=true;
      end;
    if LabelString='type_attr:' then
      begin
      LabelProcessed:=true;
      ContentString:=Copy(ContentString,2,Length(ContentString)-2);
      if InAttributeInputPair(InputTypes,ContentString)=-1 then
        begin // This input (first occurence) will be used for this attribute
        SetLength(InputTypes,Length(InputTypes)+1);
        with InputTypes[Length(InputTypes)-1] do
          begin
          Input:=InputName; // Assumes that Name is always earlier in the file than the related Attribute. It is the case now.
          Attribute:=ContentString;
          end;
        end;
      end;
    if LabelString='type_list_attr:' then
      begin
      // or even the list of type attr
      LabelProcessed:=true;
      end;
    if not LabelProcessed and (CmdLineV>=1) then
      writeln('Unknown Input component found "'+LabelString+'" with content "'+ContentString+'".');
    end;
  if InputName<>'' then
    begin
    if InputMultiple then
      begin
      SetLength(InputLists,Length(InputLists)+1);
      InputLists[Length(InputLists)-1]:=InputName;
      end
    else
      begin
      SetLength(Inputs,Length(Inputs)+1);
      Inputs[Length(Inputs)-1]:=InputName;
      end;
    end
  else
    begin
    if CmdLineV>=1 then
      writeln('Input has no Name');
    end;
  end;
procedure ProcessOutputArg(var AOutput:string);
  var
    LabelString:               string='';
    ContentString:             string='';
    LabelProcessed:            boolean;
    OutputName:                string='';
    OutputMultiple:            boolean=false;
  begin
  while AOutput<>'' do
    begin
    ParseStringIntoThree(AOutput,LabelString,ContentString,AOutput);
    LabelProcessed:=false;
    if LabelString='is_ref:' then
      begin
      LabelProcessed:=true;
      end;
    if LabelString='name:' then
      begin
      LabelProcessed:=true;
      if OutputName='' then
        OutputName:=Copy(ContentString,2,Length(ContentString)-2)
      else
        if CmdLineV>=1 then
          writeln('Output has duplicate Name value!');
      end;
    if LabelString='number_attr:' then
      begin
      LabelProcessed:=true;
      OutputMultiple:=true;
      end;
    if LabelString='type:' then
      begin
      LabelProcessed:=true;
      end;
    if LabelString='type_attr:' then
      begin
      LabelProcessed:=true;
      end;
    if LabelString='type_list_attr:' then
      begin
      LabelProcessed:=true;
      OutputMultiple:=true;
      end;
    if not LabelProcessed and (CmdLineV>=1) then
      writeln('Unknown Output component found "'+LabelString+'" with content "'+ContentString+'".');
    end;
  if OutputName<>'' then
    begin
    if OutputMultiple then
      begin
      SetLength(OutputLists,Length(OutputLists)+1);
      OutputLists[Length(OutputLists)-1]:=OutputName;
      end
    else
      begin
      SetLength(Outputs,Length(Outputs)+1);
      Outputs[Length(Outputs)-1]:=OutputName;
      end;
    end
  else
    begin
    if CmdLineV>=1 then
      writeln('Output has no Name');
    end;
  end;
procedure ProcessAttr(var AAttr:string);
  var
    LabelString:               string='';
    ContentString:             string='';
    AttrName:                  string='';
    AttrType:                  string='';
    AttrDefault:               boolean=false;
    LabelProcessed:            boolean;
  begin
  while AAttr<>'' do
    begin
    ParseStringIntoThree(AAttr,LabelString,ContentString,AAttr);
    LabelProcessed:=false;
    if LabelString='allowed_values' then
      begin
      LabelProcessed:=true;
      // no need to do anything, it is checked at run-time
      end;
    if LabelString='default_value' then
      begin
      LabelProcessed:=true;
      if not AttrDefault then
        begin
        AttrDefault:=true;
        end
      else
        begin
        writeln('Attr has duplicate Default value!');
        end;
      end;
    if LabelString='has_minimum:' then
      begin
      LabelProcessed:=true;
      // no need to do anything, it is checked at run-time
      end;
    if LabelString='minimum:' then
      begin
      LabelProcessed:=true;
      // no need to do anything, it is checked at run-time
      end;
    if LabelString='name:' then
      begin
      LabelProcessed:=true;
      if AttrName='' then
        AttrName:=Copy(ContentString,2,Length(ContentString)-2)
      else
        writeln('Attr has duplicate Name value!');
      end;
    if LabelString='type:' then
      begin
      LabelProcessed:=true;
      if AttrType='' then
        AttrType:=Copy(ContentString,2,Length(ContentString)-2)
      else
        writeln('Attr has duplicate Type value!');
      end;
    if not LabelProcessed then
      writeln('Unknown Attr component found "'+LabelString+'" with content "'+ContentString+'".');
    end;
  if (AttrName<>'') and (AttrType<>'') then
    begin
    SetLength(AttributeNames,Length(AttributeNames)+1);
    SetLength(AttributeTypes,Length(AttributeTypes)+1);
    SetLength(AttributeDefaults,Length(AttributeDefaults)+1);
    AttributeNames[Length(AttributeNames)-1]:=AttrName;
    AttributeTypes[Length(AttributeTypes)-1]:=AttrType;
    AttributeDefaults[Length(AttributeDefaults)-1]:=AttrDefault;
    end
  else
    writeln('Attr  has no Name or Type');
  end;
procedure ProcessOps(const AOpName:string; var AOp:string);
  var
    LabelString:               string=         '';
    ContentString:             string=         '';
    LabelProcessed:            boolean;
  begin
  if CmdLineV>=2 then
    write('Processing Ops: '+AOpName+'                                            '+#$0d);
  SetLength(Inputs,0);
  SetLength(InputLists,0);
  SetLength(Outputs,0);
  SetLength(OutputLists,0);
  SetLength(AttributeNames,0);
  SetLength(AttributeTypes,0);
  SetLength(AttributeDefaults,0);
  SetLength(InputTypes,0);
  while AOp<>'' do
    begin
    ParseStringIntoThree(AOp,LabelString,ContentString,AOp);
    LabelProcessed:=false;
    if LabelString='allows_uninitialized:' then
      begin
      LabelProcessed:=true;
      end;
    if LabelString='allows_uninitialized_input:' then
      begin
      LabelProcessed:=true;
      end;
    if LabelString='input_arg' then
      begin
      LabelProcessed:=true;
      ProcessInputArg(ContentString);
      end;
    if LabelString='output_arg' then
      begin
      LabelProcessed:=true;
      ProcessOutputArg(ContentString);
      end;
    if LabelString='attr' then
      begin
      LabelProcessed:=true;
      ProcessAttr(ContentString);
      end;
    if LabelString='is_aggregate:' then
      begin
      LabelProcessed:=true;
      end;
    if LabelString='is_commutative:' then
      begin
      LabelProcessed:=true;
      end;
    if LabelString='is_stateful:' then
      begin
      LabelProcessed:=true;
      end;
    if LabelString='deprecation' then
      begin
      LabelProcessed:=true;
      end;
    if (not LabelProcessed) and (CmdLineV>=1) then
      writeln('Unknown component found "'+LabelString+'" with content "'+ContentString+'" in '+AOpName);
    end;
  end;
var
  GraphInterface:              string=         '';
  GraphImplementation:         string=         '';
  EagerInterface:              string=         '';
  EagerImplementation:         string=         '';
  GraphCount:                  integer=        0;
  EagerCount:                  integer=        0;
procedure GenerateGraph(const AOpName:string);
  var
    OneCall:                   string=         '';
    OneExecution:              string=         '';
    PascalType:                string;
    i:                         integer;
  begin
  // first in any case make full version
  OneCall:=CmdLineG+AOpName+'(';
  OneExecution:='  result:=AddOper('''+AOpName+''',[';
  for i:=0 to length(Inputs)-1 do
    begin
    OneCall:=OneCall+'const I_'+Inputs[i]+':string; '; // Something is needed, because of input names like "var". "I" is not sufficient, because of "f" giving "If".
    OneExecution:=OneExecution+'I_'+Inputs[i]+',';
    end;
  if OneExecution[Length(OneExecution)]=',' then
    SetLength(OneExecution,Length(OneExecution)-1);
  OneExecution:=OneExecution+'],[';
  for i:=0 to length(InputLists)-1 do
    begin
    OneCall:=OneCall+'const IL_'+InputLists[i]+':string; ';
    OneExecution:=OneExecution+'IL_'+InputLists[i]+',';
    end;
  if OneExecution[Length(OneExecution)]=',' then
    SetLength(OneExecution,Length(OneExecution)-1);
  OneExecution:=OneExecution+'],[],[';
  for i:=0 to length(Outputs)-1 do
    begin
    OneCall:=OneCall+'const O_'+Outputs[i]+':string; ';
    OneExecution:=OneExecution+'O_'+Outputs[i]+',';
    end;
  for i:=0 to length(OutputLists)-1 do
    begin
    OneCall:=OneCall+'const OL_'+OutputLists[i]+':string; ';
    OneExecution:=OneExecution+'OL_'+OutputLists[i]+',';
    end;
  if OneExecution[Length(OneExecution)]=',' then
    SetLength(OneExecution,Length(OneExecution)-1);
  OneExecution:=OneExecution+'],[';
  for i:=0 to length(AttributeNames)-1 do
    begin
    OneCall:=OneCall+'const A_'+AttributeNames[i]+':';
    OneExecution:=OneExecution+''''+AttributeNames[i]+''',';
    PascalType:='';
    if AttributeTypes[i]='bool' then
      PascalType:='boolean';
    if AttributeTypes[i]='float' then
      PascalType:='real';
    if AttributeTypes[i]='func' then
      PascalType:='TF_Function';
    if AttributeTypes[i]='int' then
      PascalType:='integer';
    if AttributeTypes[i]='list(float)' then
      PascalType:='array of real';
    if AttributeTypes[i]='list(func)' then
      PascalType:='array of TF_Function';
    if AttributeTypes[i]='list(int)' then
      PascalType:='array of integer';
    if AttributeTypes[i]='list(shape)' then
      PascalType:='array of TF_Shape';
    if AttributeTypes[i]='list(string)' then
      PascalType:='array of string';
    if AttributeTypes[i]='list(type)' then
      PascalType:='array of TF_DataType';
    if AttributeTypes[i]='shape' then
      PascalType:='TF_Shape';
    if AttributeTypes[i]='string' then
      PascalType:='string';
    if AttributeTypes[i]='tensor' then
      PascalType:='TF_TensorPtr';
    if AttributeTypes[i]='type' then
      PascalType:='TF_DataType';
    if PascalType='' then
      begin
      if CmdLineV>=1 then
        writeln('Unknown type: '+AttributeTypes[i]);
      PascalType:='boolean';
      end;
    OneCall:=OneCall+PascalType+'; ';
    end;
  if OneExecution[Length(OneExecution)]=',' then
    SetLength(OneExecution,Length(OneExecution)-1);
  OneExecution:=OneExecution+'],[';
  for i:=0 to length(AttributeTypes)-1 do
    OneExecution:=OneExecution+''''+AttributeTypes[i]+''',';
  if OneExecution[Length(OneExecution)]=',' then
    SetLength(OneExecution,Length(OneExecution)-1);
  OneExecution:=OneExecution+'],[';
  for i:=0 to length(AttributeNames)-1 do
    OneExecution:=OneExecution+'@A_'+AttributeNames[i]+',';
  if OneExecution[Length(OneExecution)]=',' then
    SetLength(OneExecution,Length(OneExecution)-1);
  OneExecution:=OneExecution+'])';
  if OneCall[Length(OneCall)]=' ' then
    SetLength(OneCall,Length(OneCall)-2);
  OneCall:=OneCall+'):boolean;'+#$0a;
  GraphInterface:=GraphInterface+'    function '+OneCall;
  GraphImplementation:=GraphImplementation+'function TGraphExt.'+OneCall+'  begin'+#$0d#$0a;
  GraphImplementation:=GraphImplementation+OneExecution+#$0d#$0a;
  GraphImplementation:=GraphImplementation+'  end;'+#$0d#$0a;
  inc(GraphCount);
  end;
procedure GenerateEager(const AOpName:string);
  var
    OneCall:                   string=         '';
    OneExecution:              string=         '';
    PascalType:                string;
    i:                         integer;
  begin
  // Specific Eager interface is only made for Operations with no InputList input and exactly one Tensor output (no OutputList)
  if Length(InputLists)>0 then exit;
  if Length(Outputs)<>1 then exit;
  if Length(OutputLists)>0 then exit;
  // first in any case make full version
  OneCall:='function '+CmdLineE+AOpName+'(';
  OneExecution:='  result:=ExecOper('''+AOpName+''',[';
  for i:=0 to length(Inputs)-1 do
    begin
    OneCall:=OneCall+'const I_'+Inputs[i]+':TF_TensorPtr; '; // Something is needed, because of input names like "var". "I" is not sufficient, because of "f" giving "If".
    OneExecution:=OneExecution+'I_'+Inputs[i]+',';
    end;
  if OneExecution[Length(OneExecution)]=',' then
    SetLength(OneExecution,Length(OneExecution)-1);
  OneExecution:=OneExecution+'],[';
  for i:=0 to length(AttributeNames)-1 do
    begin
    PascalType:='';
    if AttributeTypes[i]='bool' then
      PascalType:='boolean';
    if AttributeTypes[i]='float' then
      PascalType:='real';
    if AttributeTypes[i]='func' then
      PascalType:='string';
    if AttributeTypes[i]='int' then
      PascalType:='integer';
    if AttributeTypes[i]='list(float)' then
      PascalType:='array of real';
    if AttributeTypes[i]='list(func)' then
      PascalType:='array of string';
    if AttributeTypes[i]='list(int)' then
      PascalType:='array of integer';
    if AttributeTypes[i]='list(shape)' then
      PascalType:='array of TF_Shape';
    if AttributeTypes[i]='list(string)' then
      PascalType:='array of string';
    if AttributeTypes[i]='list(type)' then
      PascalType:='array of TF_DataType';
    if AttributeTypes[i]='shape' then
      PascalType:='TF_Shape';
    if AttributeTypes[i]='string' then
      PascalType:='string';
    if AttributeTypes[i]='tensor' then
      PascalType:='TF_TensorPtr';
    if AttributeTypes[i]='type' then
      PascalType:='TF_DataType';
    if PascalType='' then
      begin
      if CmdLineV>=1 then
        writeln('Unknown type: '+AttributeTypes[i]);
      PascalType:='boolean';
      end;
    if (InAttributeInputPair(InputTypes,AttributeNames[i])=-1) then
      OneCall:=OneCall+'const A_'+AttributeNames[i]+':'+PascalType+'; '; // only add to the call, if cannot be caluclated
    OneExecution:=OneExecution+''''+AttributeNames[i]+''',';
    end;
  if OneExecution[Length(OneExecution)]=',' then
    SetLength(OneExecution,Length(OneExecution)-1);
  OneExecution:=OneExecution+'],[';
  for i:=0 to length(AttributeTypes)-1 do
    OneExecution:=OneExecution+''''+AttributeTypes[i]+''',';
  if OneExecution[Length(OneExecution)]=',' then
    SetLength(OneExecution,Length(OneExecution)-1);
  OneExecution:=OneExecution+'],[';
  for i:=0 to length(AttributeNames)-1 do
    begin
    if (InAttributeInputPair(InputTypes,AttributeNames[i])=-1) then
      OneExecution:=OneExecution+'@A_'+AttributeNames[i]+','
    else
      OneExecution:=OneExecution+'@F_'+AttributeNames[i]+',';
    end;
  if OneExecution[Length(OneExecution)]=',' then
    SetLength(OneExecution,Length(OneExecution)-1);
  OneExecution:=OneExecution+'],[';
  for i:=0 to length(Inputs)-1 do
    begin
    OneCall:=OneCall+'const D_'+Inputs[i]+':boolean=false; ';
    OneExecution:=OneExecution+'D_'+Inputs[i]+',';
    end;
  if OneExecution[Length(OneExecution)]=',' then
    SetLength(OneExecution,Length(OneExecution)-1);
  OneExecution:=OneExecution+'])';
  if OneCall[Length(OneCall)]=' ' then
    SetLength(OneCall,Length(OneCall)-2);
  OneCall:=OneCall+'):TF_TensorPtr;'+#$0a;
  EagerInterface:=EagerInterface+OneCall;
  EagerImplementation:=EagerImplementation+OneCall;
  if Length(InputTypes)>0 then
    EagerImplementation:=EagerImplementation+'  var'+#$0d#$0a;
  for i:=0 to Length(InputTypes)-1 do
    EagerImplementation:=EagerImplementation+'    F_'+InputTypes[i].Attribute+':TF_DataType;'+#$0d#$0a;
  EagerImplementation:=EagerImplementation+'  begin'+#$0d#$0a;
  for i:=0 to Length(InputTypes)-1 do
    EagerImplementation:=EagerImplementation+'  F_'+InputTypes[i].Attribute+':=TF_TensorType(I_'+InputTypes[i].Input+');'+#$0d#$0a;
  EagerImplementation:=EagerImplementation+OneExecution+#$0d#$0a;
  EagerImplementation:=EagerImplementation+'  end;'+#$0d#$0a;
  inc(EagerCount);
  end;
procedure ProcessOp(var AOp:string);
  var
    LabelString:               string=         '';
    ContentString:             string=         '';
  begin
  ParseStringIntoThree(AOp,LabelString,ContentString,AOp);
  if LabelString='name:' then
    begin
    if (ContentString[1]='"') and (ContentString[Length(ContentString)]='"') then
      begin
      ContentString:=Copy(ContentString,2,Length(ContentString)-2);
      ProcessOps(ContentString,AOp);
      if (CmdLineU=1) or (CmdLineU=3) then
        GenerateGraph(ContentString);
      if (CmdLineU=2) or (CmdLineU=3) then
        GenerateEager(ContentString);
      end
    else
      begin
      if CmdLineV>=1 then
        writeln('Ops name is not included in "" for '+ContentString);
      end;
    end
  else
    begin
    if CmdLineV>=1 then
      writeln('"name:" expected "'+LabelString+'" received');
    end;
  end;
const
  TDB='//  #TemplateDescriptionBegin';
  TDE='//  #TemplateDescriptionEnd';
  GDB='//  #GraphDescriptionBegin';
  GDE='//  #GraphDescriptionEnd';
  EDB='//  #EagerDescriptionBegin';
  EDE='//  #EagerDescriptionEnd';
  GNB='//  #GraphInterfaceBegin';
  GNF='//  #GraphInterfaceFill';
  GNE='//  #GraphInterfaceEnd';
  ENB='//  #EagerInterfaceBegin';
  ENF='//  #EagerInterfaceFill';
  ENE='//  #EagerInterfaceEnd';
  GMB='//  #GraphImplementationBegin';
  GMF='//  #GraphImplementationFill';
  GME='//  #GraphImplementationEnd';
  EMB='//  #EagerImplementationBegin';
  EMF='//  #EagerImplementationFill';
  EME='//  #EagerImplementationEnd';
function ProcessFile:boolean;
  var
    LabelString:               string=         '';
    ContentString:             string=         '';
    OperationCount:            integer=        0;
  begin
  if CmdLineV>=1 then
    begin
    writeln('Wrapper Maker by Zsolt Szakaly, 2020');
    end;
  if CmdLineV>=2 then
    begin
    writeln('Processing input file. Actual parameters:');
    writeln('TensorFlow definition file (-S): ',CmdLineS);
    writeln('Template file              (-T): ',CmdLineT);
    writeln('Output (unit) file         (-O): ',CmdLineO);
    write  ('Wrapper unit generated for (-U): ');
    case CmdLineU of
      1:writeln('1 - Only TGraphExt.',CmdLineG,'<oper>');
      2:writeln('2 - Only Eager ',CmdLineE,'<oper>');
      3:writeln('3 - Both TGraphExt.',CmdLineG,'<oper> and Eager ',CmdLineE,'<oper>');
      end;
    if (CmdLineU=1) or (CmdLineU=3) then
      writeln('Prefix for TGraphExt       (-G): ',CmdLineG,'<oper>');
    if CmdLineU>=2 then
      writeln('Prefix for Eager           (-E): ',CmdLineE,'<oper>');
    writeln('Verbose level              (-V): ',CmdLineV);
    end;
  while OpsPbtxt<>'' do
    begin
    ParseStringIntoThree(OpsPbtxt,LabelString,ContentString,OpsPbtxt);
    if LabelString='op' then
      begin
      ProcessOp(ContentString);
      inc(OperationCount);
      end
    else
      begin
      if CmdLineV>=1 then
        writeln('"op" expected "'+LabelString+'" received');
      end;
    end;
  TemplateStr:=Copy(TemplateStr,1,Pos(TDB,TemplateStr)-1)+Copy(TemplateStr,Pos(TDE,TemplateStr)+Length(TDE)+2);
  if (CmdLineU=1) or (CmdLineU=3) then
    begin // TGraphExt is generated
    TemplateStr:=Copy(TemplateStr,1,Pos(GDB,TemplateStr)-1)+Copy(TemplateStr,Pos(GDB,TemplateStr)+Length(GDB)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(GDE,TemplateStr)-1)+Copy(TemplateStr,Pos(GDE,TemplateStr)+Length(GDE)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(GNB,TemplateStr)-1)+Copy(TemplateStr,Pos(GNB,TemplateStr)+Length(GNB)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(GNF,TemplateStr)-1)+GraphInterface+Copy(TemplateStr,Pos(GNF,TemplateStr)+Length(GNF)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(GNE,TemplateStr)-1)+Copy(TemplateStr,Pos(GNE,TemplateStr)+Length(GNE)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(GMB,TemplateStr)-1)+Copy(TemplateStr,Pos(GMB,TemplateStr)+Length(GMB)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(GMF,TemplateStr)-1)+GraphImplementation+Copy(TemplateStr,Pos(GMF,TemplateStr)+Length(GMF)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(GME,TemplateStr)-1)+Copy(TemplateStr,Pos(GME,TemplateStr)+Length(GME)+2);
    end
  else
    begin // TGraphExt is not generated, references removed
    TemplateStr:=Copy(TemplateStr,1,Pos(GDB,TemplateStr)-1)+Copy(TemplateStr,Pos(GDE,TemplateStr)+Length(GDE)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(GNB,TemplateStr)-1)+Copy(TemplateStr,Pos(GNE,TemplateStr)+Length(GNE)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(GMB,TemplateStr)-1)+Copy(TemplateStr,Pos(GME,TemplateStr)+Length(GME)+2);
    end;
  if (CmdLineU=2) or (CmdLineU=3) then
    begin // Exec<oper> is generated
    TemplateStr:=Copy(TemplateStr,1,Pos(EDB,TemplateStr)-1)+Copy(TemplateStr,Pos(EDB,TemplateStr)+Length(EDB)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(EDE,TemplateStr)-1)+Copy(TemplateStr,Pos(EDE,TemplateStr)+Length(EDE)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(ENB,TemplateStr)-1)+Copy(TemplateStr,Pos(ENB,TemplateStr)+Length(ENB)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(ENF,TemplateStr)-1)+EagerInterface+Copy(TemplateStr,Pos(ENF,TemplateStr)+Length(ENF)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(ENE,TemplateStr)-1)+Copy(TemplateStr,Pos(ENE,TemplateStr)+Length(ENE)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(EMB,TemplateStr)-1)+Copy(TemplateStr,Pos(EMB,TemplateStr)+Length(EMB)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(EMF,TemplateStr)-1)+EagerImplementation+Copy(TemplateStr,Pos(EMF,TemplateStr)+Length(EMF)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(EME,TemplateStr)-1)+Copy(TemplateStr,Pos(EME,TemplateStr)+Length(EME)+2);
    end
  else
    begin // Exec<oper> is not generated, references removed
    TemplateStr:=Copy(TemplateStr,1,Pos(EDB,TemplateStr)-1)+Copy(TemplateStr,Pos(EDE,TemplateStr)+Length(EDE)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(ENB,TemplateStr)-1)+Copy(TemplateStr,Pos(ENE,TemplateStr)+Length(ENE)+2);
    TemplateStr:=Copy(TemplateStr,1,Pos(EMB,TemplateStr)-1)+Copy(TemplateStr,Pos(eME,TemplateStr)+Length(EME)+2);
    end;
  SaveUnit;
  result:=true;
  if CmdLineV>=1 then
    begin
    writeln;
    writeln('Wrapper unit completed');
    end;
  if CmdLineV>=2 then
    writeln('Processed ',OperationCount,' operations, added ',GraphCount,' TGraph.',CmdLineG,'<oper> and ',EagerCount,
             ' ',CmdLineE,'<oper> functions.');
  end;
function RunGenerator:boolean;
  begin
  result:=
    GetOpsPbtxt and
    RemoveExtraSpaces and
    LoadTemplate and
    ProcessFile;
  end;

// The Main program
begin
if ProcessCommandLine then // no error in the command line
  begin
  if CmdLineH>0 then // help requested
    PrintHelp
  else
    RunGenerator;
  end;
end.


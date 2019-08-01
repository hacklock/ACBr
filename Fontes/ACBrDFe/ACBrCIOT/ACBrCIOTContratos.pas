
{$I ACBr.inc}

unit ACBrCIOTContratos;

interface

uses
  Classes, SysUtils, Dialogs, Forms, StrUtils,
  ACBrCIOTConfiguracoes, ACBrDFeUtil,
  pcnCIOT, pcnCIOTR, pcnCIOTW, pcnConversao, pcnAuxiliar, pcnLeitor;

type

  { Contrato }

  Contrato = class(TCollectionItem)
  private
    FCIOT: TCIOT;
    FCIOTW: TCIOTW;
    FCIOTR: TCIOTR;

    FXMLAssinado: String;
    FXMLOriginal: String;
    FAlertas: String;
    FNomeArq: String;

    function GetConfirmado: Boolean;
    function GetProcessado: Boolean;

    function GetMsg: String;
    function GetNumID: String;
    function GetXMLAssinado: String;
    procedure SetXML(AValue: String);
    procedure SetXMLOriginal(AValue: String);
    function CalcularNomeArquivo: String;
    function CalcularPathArquivo: String;
    function CalcularNomeArquivoCompleto(NomeArquivo: String = '';
      PathArquivo: String = ''): String;
  public
    constructor Create(Collection2: TCollection); override;
    destructor Destroy; override;

    procedure Assinar;

    function LerXML(const AXML: AnsiString): Boolean;
    function GerarXML: String;
    function GravarXML(const NomeArquivo: String = ''; PathArquivo: String = ''): Boolean;
    function GravarStream(AStream: TStream): Boolean;

    procedure EnviarEmail(sPara, sAssunto: String; sMensagem: TStrings = nil;
      EnviaPDF: Boolean = True; sCC: TStrings = nil; Anexos: TStrings = nil;
      sReplyTo: TStrings = nil);

    property NomeArq: String read FNomeArq write FNomeArq;
    property CIOT: TCIOT read FCIOT;

    // Atribuir a "XML", faz o componente transferir os dados lido para as propriedades internas e "XMLAssinado"
    property XML: String         read FXMLOriginal   write SetXML;
    // Atribuir a "XMLOriginal", reflete em XMLAssinado, se existir a tag de assinatura
    property XMLOriginal: String read FXMLOriginal   write SetXMLOriginal;
    property XMLAssinado: String read GetXMLAssinado write FXMLAssinado;
    property Confirmado: Boolean read GetConfirmado;
    property Processado: Boolean read GetProcessado;
    property Msg: String read GetMsg;
    property NumID: String read GetNumID;
    property Alertas: String read FAlertas;
  end;

  { TContratos }

  TContratos = class(TOwnedCollection)
  private
    FACBrCIOT: TComponent;
    FConfiguracoes: TConfiguracoesCIOT;

    function GetItem(Index: integer): Contrato;
    procedure SetItem(Index: integer; const Value: Contrato);

  public
    constructor Create(AOwner: TPersistent; ItemClass: TCollectionItemClass);

    procedure GerarCIOT;
    procedure Assinar;

    function Add: Contrato;
    function Insert(Index: integer): Contrato;

    property Items[Index: integer]: Contrato read GetItem write SetItem; default;

    function GetNamePath: String; override;
    // Incluido o Parametro AGerarCIOT que determina se ap�s carregar os dados do CIOT
    // para o componente, ser� gerado ou n�o novamente o XML do CIOT.
    function LoadFromFile(CaminhoArquivo: String; AGerarCIOT: Boolean = True): Boolean;
    function LoadFromStream(AStream: TStringStream; AGerarCIOT: Boolean = True): Boolean;
    function LoadFromString(AXMLString: String; AGerarCIOT: Boolean = True): Boolean;
    function GravarXML(PathNomeArquivo: String = ''): Boolean;

    property ACBrCIOT: TComponent read FACBrCIOT;
  end;

implementation

uses
  ACBrCIOT, ACBrUtil, pcnConversaoCIOT, synautil;

{ Documento }

constructor Contrato.Create(Collection2: TCollection);
begin
  inherited Create(Collection2);
  FCIOT := TCIOT.Create;
  FCIOTW := TCIOTW.Create(FCIOT);
  FCIOTR := TCIOTR.Create(FCIOT);

  with TACBrCIOT(TContratos(Collection).ACBrCIOT) do
  begin
    FCIOTW.Integradora := Configuracoes.Geral.Integradora;

    FCIOT.Integradora.usuario        := Configuracoes.Geral.Usuario;
    FCIOT.Integradora.senha          := Configuracoes.Geral.Senha;
    FCIOT.Integradora.HashIntegrador := Configuracoes.Geral.HashIntegrador;
  end;
end;

destructor Contrato.Destroy;
begin
  FCIOT.Free;
  FCIOTW.Free;
  FCIOTR.Free;

  inherited Destroy;
end;

procedure Contrato.Assinar;
var
  XMLStr: String;
  XMLUTF8: AnsiString;
begin
  // Gera novamente, para processar propriedades que podem ter sido modificadas
  XMLStr := GerarXML;

  // XML j� deve estar em UTF8, para poder ser assinado //
  XMLUTF8 := ConverteXMLtoUTF8(XMLStr);

  with TACBrCIOT(TContratos(Collection).ACBrCIOT) do
  begin
    FXMLAssinado := String(XMLUTF8); // SSL.Assinar(String(XMLUTF8), 'CIOT', 'infCIOT');
    // SSL.Assinar() sempre responde em UTF8...
    FXMLOriginal := RemoverDeclaracaoXML(FXMLAssinado);

    if Configuracoes.Arquivos.Salvar then
    begin
      if NaoEstaVazio(NomeArq) then
        Gravar(NomeArq, FXMLOriginal)
      else
        Gravar(CalcularNomeArquivoCompleto(), FXMLOriginal);
    end;
  end;
end;

function Contrato.LerXML(const AXML: AnsiString): Boolean;
var
  XMLStr: String;
begin
  XMLOriginal := AXML;  // SetXMLOriginal() ir� verificar se AXML est� em UTF8

  { Verifica se precisa converter "AXML" de UTF8 para a String nativa da IDE.
    Isso � necess�rio, para que as propriedades fiquem com a acentua��o correta }
  XMLStr := ParseText(AXML, True, XmlEhUTF8(AXML));

  FCIOTR.Leitor.Arquivo := XMLStr;
  FCIOTR.LerXml;

  Result := True;
end;

function Contrato.GravarXML(const NomeArquivo: String; PathArquivo: String): Boolean;
begin
  if EstaVazio(FXMLOriginal) then
    GerarXML;

  FNomeArq := CalcularNomeArquivoCompleto(NomeArquivo, PathArquivo);

  Result := TACBrCIOT(TContratos(Collection).ACBrCIOT).Gravar(FNomeArq, FXMLOriginal);
end;

function Contrato.GravarStream(AStream: TStream): Boolean;
begin
  if EstaVazio(FXMLOriginal) then
    GerarXML;

  AStream.Size := 0;
  WriteStrToStream(AStream, AnsiString(FXMLOriginal));
  Result := True;
end;

procedure Contrato.EnviarEmail(sPara, sAssunto: String; sMensagem: TStrings;
  EnviaPDF: Boolean; sCC: TStrings; Anexos: TStrings; sReplyTo: TStrings);
var
//  NomeArq : String;
  AnexosEmail:TStrings;
  StreamCIOT : TMemoryStream;
begin
  if not Assigned(TACBrCIOT(TContratos(Collection).ACBrCIOT).MAIL) then
    raise EACBrCIOTException.Create('Componente ACBrMail n�o associado');

  AnexosEmail := TStringList.Create;
  StreamCIOT := TMemoryStream.Create;
  try
    AnexosEmail.Clear;
    if Assigned(Anexos) then
      AnexosEmail.Assign(Anexos);

    with TACBrCIOT(TContratos(Collection).ACBrCIOT) do
    begin
      GravarStream(StreamCIOT);
      (*
      if (EnviaPDF) then
      begin
        if Assigned(DACIOT) then
        begin
          DACIOT.ImprimirDACIOTPDF(FCIOT);
          NomeArq := PathWithDelim(DACIOT.PathPDF) + NumID + '-CIOT.pdf';
          AnexosEmail.Add(NomeArq);
        end;
      end;
      *)
      EnviarEmail( sPara, sAssunto, sMensagem, sCC, AnexosEmail, StreamCIOT,
                   NumID + '-CIOT.xml', sReplyTo);
    end;
  finally
    AnexosEmail.Free;
    StreamCIOT.Free;
  end;
end;

function Contrato.GerarXML: String;
begin
  with TACBrCIOT(TContratos(Collection).ACBrCIOT) do
  begin
    FCIOTW.CIOTWClass.Gerador.Opcoes.FormatoAlerta  := Configuracoes.Geral.FormatoAlerta;
    FCIOTW.CIOTWClass.Gerador.Opcoes.RetirarAcentos := Configuracoes.Geral.RetirarAcentos;
    FCIOTW.CIOTWClass.Gerador.Opcoes.RetirarEspacos := Configuracoes.Geral.RetirarEspacos;
    FCIOTW.CIOTWClass.Gerador.Opcoes.IdentarXML     := Configuracoes.Geral.IdentarXML;

    FCIOTW.Integradora := Configuracoes.Geral.Integradora;

    pcnAuxiliar.TimeZoneConf.Assign( Configuracoes.WebServices.TimeZoneConf );
  end;

  FCIOTW.GerarXml;
  XMLOriginal := FCIOTW.CIOTWClass.Gerador.ArquivoFormatoXML;

  if NaoEstaVazio(FNomeArq) then
    FNomeArq := CalcularNomeArquivoCompleto('', ExtractFilePath(FNomeArq));

  FAlertas := ACBrStr( FCIOTW.CIOTWClass.Gerador.ListaDeAlertas.Text );
  Result := FXMLOriginal;
end;

function Contrato.CalcularNomeArquivo: String;
var
  xID: String;
begin
  xID := Self.NumID;

  if EstaVazio(xID) then
    raise EACBrCIOTException.Create('ID Inv�lido. Imposs�vel Salvar XML');

  Result := xID + '-CIOT.xml';
end;

function Contrato.CalcularPathArquivo: String;
begin
  with TACBrCIOT(TContratos(Collection).ACBrCIOT) do
  begin
    Result := PathWithDelim(Configuracoes.Arquivos.GetPathCIOT(Now, Configuracoes.Geral.CNPJEmitente));
  end;
end;

function Contrato.CalcularNomeArquivoCompleto(NomeArquivo: String;
  PathArquivo: String): String;
var
  PathNoArquivo: String;
begin
  if EstaVazio(NomeArquivo) then
    NomeArquivo := CalcularNomeArquivo;

  PathNoArquivo := ExtractFilePath(NomeArquivo);
  if EstaVazio(PathNoArquivo) then
  begin
    if EstaVazio(PathArquivo) then
      PathArquivo := CalcularPathArquivo
    else
      PathArquivo := PathWithDelim(PathArquivo);
  end
  else
    PathArquivo := '';

  Result := PathArquivo + NomeArquivo;
end;

function Contrato.GetConfirmado: Boolean;
begin
//  Result := TACBrCIOT(TContratos(Collection).ACBrCIOT).cStatConfirmado(
//    FCIOT.procCIOT.cStat);
  Result := True;
end;

function Contrato.GetProcessado: Boolean;
begin
//  Result := TACBrCIOT(TContratos(Collection).ACBrCIOT).cStatProcessado(
//    FCIOT.procCIOT.cStat);
  Result := True;
end;

function Contrato.GetMsg: String;
begin
//  Result := FCIOT.procCIOT.xMotivo;
  Result := '';
end;

function Contrato.GetNumID: String;
begin
  Result := FormatDateTime('yyyymmddhhnnss', Now);
end;

function Contrato.GetXMLAssinado: String;
begin
  if EstaVazio(FXMLAssinado) then
    Assinar;

  Result := FXMLAssinado;
end;

procedure Contrato.SetXML(AValue: String);
begin
  LerXML(AValue);
end;

procedure Contrato.SetXMLOriginal(AValue: String);
var
  XMLUTF8: String;
begin
  { Garante que o XML informado est� em UTF8, se ele realmente estiver, nada
    ser� modificado por "ConverteXMLtoUTF8"  (mantendo-o "original") }
  XMLUTF8 := ConverteXMLtoUTF8(AValue);

  FXMLOriginal := XMLUTF8;

  if XmlEstaAssinado(FXMLOriginal) then
    FXMLAssinado := FXMLOriginal
  else
    FXMLAssinado := '';
end;

{ TContratos }

constructor TContratos.Create(AOwner: TPersistent; ItemClass: TCollectionItemClass);
begin
  if not (AOwner is TACBrCIOT) then
    raise EACBrCIOTException.Create('AOwner deve ser do tipo TACBrCIOT');

  inherited;

  FACBrCIOT := TACBrCIOT(AOwner);
  FConfiguracoes := TACBrCIOT(FACBrCIOT).Configuracoes;
end;

function TContratos.Add: Contrato;
begin
  Result := Contrato(inherited Add);
end;

procedure TContratos.Assinar;
var
  i: integer;
begin
  for i := 0 to Self.Count - 1 do
    Self.Items[i].Assinar;
end;

procedure TCOntratos.GerarCIOT;
var
  i: integer;
begin
  for i := 0 to Self.Count - 1 do
    Self.Items[i].GerarXML;
end;

function TContratos.GetItem(Index: integer): Contrato;
begin
  Result := Contrato(inherited Items[Index]);
end;

function TContratos.GetNamePath: String;
begin
  Result := 'Contrato';
end;

function TContratos.Insert(Index: integer): Contrato;
begin
  Result := Contrato(inherited Insert(Index));
end;

procedure TContratos.SetItem(Index: integer; const Value: Contrato);
begin
  Items[Index].Assign(Value);
end;

function TContratos.LoadFromFile(CaminhoArquivo: String;
  AGerarCIOT: Boolean = True): Boolean;
var
  XMLUTF8: AnsiString;
  i, l: integer;
  MS: TMemoryStream;
begin
  MS := TMemoryStream.Create;
  try
    MS.LoadFromFile(CaminhoArquivo);
    XMLUTF8 := ReadStrFromStream(MS, MS.Size);
  finally
    MS.Free;
  end;

  l := Self.Count; // Indice da �ltima nota j� existente
  Result := LoadFromString(String(XMLUTF8), AGerarCIOT);

  if Result then
  begin
    // Atribui Nome do arquivo a novas notas inseridas //
    for i := l to Self.Count - 1 do
      Self.Items[i].NomeArq := CaminhoArquivo;
  end;
end;

function TContratos.LoadFromStream(AStream: TStringStream;
  AGerarCIOT: Boolean = True): Boolean;
var
  AXML: AnsiString;
begin
  AStream.Position := 0;
  AXML := ReadStrFromStream(AStream, AStream.Size);

  Result := Self.LoadFromString(String(AXML), AGerarCIOT);
end;

function TContratos.LoadFromString(AXMLString: String;
  AGerarCIOT: Boolean = True): Boolean;
var
  AXML: AnsiString;
  N: integer;

  function PosCIOT: integer;
  begin
    Result := pos('</CIOT>', AXMLString);
  end;

begin
  N := PosCIOT;
  while N > 0 do
  begin
    AXML := copy(AXMLString, 1, N + 6);
    AXMLString := Trim(copy(AXMLString, N + 7, length(AXMLString)));

    with Self.Add do
    begin
      LerXML(AXML);

      if AGerarCIOT then // Recalcula o XML
        GerarXML;
    end;

    N := PosCIOT;
  end;

  Result := Self.Count > 0;
end;

function TContratos.GravarXML(PathNomeArquivo: String): Boolean;
var
  i: integer;
  NomeArq, PathArq : String;
begin
  Result := True;
  i := 0;
  while Result and (i < Self.Count) do
  begin
    PathArq := ExtractFilePath(PathNomeArquivo);
    NomeArq := ExtractFileName(PathNomeArquivo);
    Result := Self.Items[i].GravarXML(NomeArq, PathArq);
    Inc(i);
  end;
end;

end.
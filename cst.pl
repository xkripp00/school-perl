#!usr/bin/perl

#CST:xkripp00

# pozn.: fcie prepinacov su podobne, preto je okomentovana poriadne iba prva, prep_k()
# v ostatnych su uz len komentovane veci, co sa nepodobaju na prvu

use strict;
use Cwd 'abs_path';		# ziskanie absolutnej cesty
use File::Find;			# prechadzanie adresarovej struktury
use Getopt::Long qw(Configure GetOptions);	# nacitanie parametrov pomocou GetOptions
Configure("bundling");

# fcia vypisujuca napovedu
sub napoveda()
{
	print "Projekt do predmetu IPP
Autor: Martin Krippel
xkripp00\@stud.fit.vutbr.cz
Varianta: CST - C Stats
Zadanie: Skript v jazyku Perl ma na zakdlade zadanych parametrov
         vypisat statisticke udaje zo suborov .c a .h
Parametre:
--help: vypise tuto napovedu, nekombinovatelny s ostatnymi parametrami
--input=fileordir: vstupny subor alebo adresar, pri nezadani parametra
		   sa berie aktualny adresar
--nosubdir: analyzuju sa len subory z aktualneho adresara,
	    nekombinovatelny s --input
--output=filename: zadany vystupny textovy subor, pri nezadani parametra
		   sa vypisuju vysledky na standardny vystup
-k: vypise pocet vsetkych vyskytov klucovych slov
-o: vypise pocet vyskytov jednoduchych operatorov
-i: vypise pocet vyskytov vsetkych identifikatorov
-w=pattern: vypise pocet vsetkych vyskytov daneho vzoru
-c: vypise pocet znakov komentarov
-p: subory sa budu vypisovat bez absolutnej cesty k suboru

Parametre -k, -o, -i, -w, -c sa nesmu kombinovat

Priklad spustenia:
	perl cst.pl --help
	perl cst.pl --input=main.c -o -p\n\n";

}
our @subory;	# pole kam sa ulozia nazvy suborov
# ak je to subor, ulozi sa do pola, subrutina pre find (wanted)
sub ziskaj_subory()
{
	push @subory, $File::Find::name if(-f);
}
# ak sa ma prehladavat len aktualny adresar (--nosubdir), tak sa pouzije subrutina "pre" vo find (preprocess)
sub pre
{
	return grep {not -d} @_;
}

##############################
our($kom, $ret, $kom_1r, $makr, $pocet_c);	# stavy, v kt. sa moze nachadzat mazanie riadku + pocet znakov komentarov
our @s_cestou;  # pole suborov bez relativnej cesty
our $celkom = 0;	# pocet celkovo vsetkych hladanych udajov
our @vysledky;	# vysledky z jednotlivych suborov
# fcia na odstranenie komentarov, retazcov a makier zo suboru
# 2 parametre: 1) jeden riadok zo suboru
#	       2) stav sa jedna o novy subor
# fcia zaroven pocita pocet znakov v komentaroch
sub odstranit($$)
{
	my $s = @_[0];
	my $stav = @_[1];
	if($stav == 1)	# je novy subor, treba inicializovat stavy
	{
		$kom = $ret = $kom_1r = $makr = 0;
	}
	while(1)	# nekonecny cyklus, ktory spracovava riadok
	{
		if($kom == 1) # stav - blokovy komentar sa neskoncil na konci predchadzajuceho riadka
		{
			if($s =~ s/^(.*?\*\/)//g)	# komentar na danom riadku skoncil
			{
				$pocet_c += length($1); 	# ratanie poctu znakov komentarov
				$kom = 0;
				next;
			}
			else		# komentar pokracuje aj na dalsom riadku, zmaze cely riadok
			{
				$pocet_c += length($s) + 1;
				$s = "";
			}
		}
		if($ret == 1)	# stav - retazec
		{
			if($s =~ s/[^"]*?"//g)		# retazec skoncil na danom riadku
			{
				$ret = 0;
				next;
			}
			else	# retazec pokracuje
			{
				$s =~ s/.*//g;
			}
		}
		if($kom_1r == 1)	# stav - jednoriadkovy komentar pokracujuci na dalsom riadku
		{
			if($s =~ s/^(.*\\)$//g)	# koniec komentara
			{
				$pocet_c += length($1) + 1;
				$kom_1r = 1;
			}
			else	# komentar pokracuje na dalsom riadku
			{
				$pocet_c += length($s) + 1;
				$s = "";
				$kom_1r = 0;
			}
		}
		if($makr == 1)	# stav - makro
		{
			if($s =~ s/^.*\\$//g) 		# koniec makra na danom riadku
			{
				$makr = 1;
			}
			else		# makro pokracuje
			{
				$s =~ s/.*//g;
				$makr = 0;
			}
		}
		if($kom == 0 && $ret == 0 && $kom_1r == 0 && $makr == 0) 
		{	
			next if $s =~ s/^([^"\/\'#]*)"[^"]*?"/\1/g;	# retazec na jednom riadku
			if($s =~ s/^([^"\/\'#]*)(\/\*.*?\*\/)/\1/g)	# viacriadkovy komentar na jednom riadku
			{
				$pocet_c += length($2);
				next;
			}	
			next if $s =~ s/^([^"\/\'#]*)'[^']*?'/\1/g;	# retazec v apostrofoch
			if($s =~ s/^([^"\/\'#]*)(\/\/([^\\]*\\*[^\\]+)*)[^\\]$/\1/g)	# riadkovy komentar neukonceny \
			{
				$pocet_c += length($2);
				next;
			}
			next if $s =~ s/^([^"\/\'#]*)#.*(\/\/)/\1\2/g;	#makro na jednom riadku za nim komentar
			next if $s =~ s/^([^"\/\'#]*)#.*(\/\*)/\1\2/g;	#makro na jednom riadku za nim komentar
			next if $s =~ s/^([^"\/\'#]*)#([^\\]*\\*[^\\]+)*[^\\]$/\1/g;	#makro na jednom riadku
			if($s =~ s/^([^"\/\'#]*)(\/\*.*)/\1/g)	# viacriadkovy komentar
			{
				$pocet_c += length($2) + 1;
				$kom = 1; 
			}
			$ret = 1 if($s =~ s/^([^"\/\'#]*)("[^"]*)/\1/g);	# retazec na viac riadkov
			if($s =~ s/^([^"\/\'#]*)(\/\/.*\\)$/\1/g)	# jednoriadkovy komentar na viacej riadkov	
			{
				$pocet_c += length($2) + 1;
				$kom_1r = 1; 
			}
			$makr = 1 if($s =~ s/^([^"\/\'#]*)(#.*\\$)/\1/g);	# makro na viacerych riadkoch
		}
	last;
	}
	return($s);
}
#############################
# fcia na otvorenie vstupneho suboru
# 4 parametre 1) velkost pola suborov
#	      2) indikacia parametra -p
#	      3) dany subor
# 	      4) chybovy kod pri neotvoreni suboru
#############################
sub otvor_subor($$$$)
{
	my($otvor, $k, $pp, $velkost, $j, $ec);
	$velkost = @_[0];
	shift @_;
	$pp = @_[0];
	shift @_;
	$j = @_[0];
	shift @_;
	$ec = @_[0];

	if($pp == 1)	#ak bol zadany parameter -p, musi si najst znovu celu relativnu cestu
		{
			for($k = 0; $k < $velkost; $k++)
			{
				if($s_cestou[$k] =~ /.*\/$j/)  # hlada celu relativnu cestu suboru
				{
					$otvor = open(VSTUP, "<$s_cestou[$k]");
					if($otvor != 1)
					{
						print STDERR "Nepodarilo sa otvorit vstupny subor: $s_cestou[$k]\n";
						exit($ec);
					}
					$s_cestou[$k] = "";	# danu cestu zmaze z pola (resp. prepise) aby uz rovnaky subor nebol znovu analyzovany
				}
			}
		}
		else	# nebol parameter -p, hlada v suboroch ulozenych s relativnou cestou, absolutnu cestu prida pred vypisom
		{
			$otvor = open(VSTUP, "<$j");	# otvorenie suboru
			if($otvor != 1)
			{
				print STDERR "Nepodarilo sa otvorit vstupny subor: $j\n";
				exit($ec);
			}
		}
}
#############################
# fcia poctajuca klucove slova
# 3 parametre 1) chybovy kod pri neotvoreni suboru
#	      2) indikacia, ci bol zadany parameter -p
#	      3) pole suborov, v kt. ma hladat klucove slova
#############################
sub prep_k($$@)
{
	my @klucove_slova = qw(auto break case char const continue default do double else enum extern float for goto if int inline long
		      	       register return short signed sizeof static struct switch typedef union unsigned void volatile while);
	my $ec = @_[0];
	shift @_;
	my $pp = @_[0];
	shift @_;
	my @files = @_;
	my($i, $j, $k, $riadok, $pocet_kw, $otvor, $velkost);
	my $stav = 0;
	$velkost = scalar(@files);
	# cyklus prechadzajuci subory po jednom
	for $j (@files)
	{
		otvor_subor($velkost, $pp, $j, $ec);	# otvorenie suboru $j
		$pocet_kw = 0;
		$stav = 1;
		while($riadok = <VSTUP>)	# citanie suboru
		{
			$riadok = &odstranit($riadok, $stav);	# odstranenie komentarov, . . .
			$stav = 0;
			for $i (@klucove_slova) # hladanie klucoveho slova na riadku
			{
				$pocet_kw++ if($riadok =~ /^$i[\s\*;:\(\[\{,]/g);
				while($riadok =~ /[\(\s{\{\},\*\[\)=\+\-]$i[\s\*\)\(;:\[\{,\}]/g)
				{
					$pocet_kw++;	
				}
			}	
		}
		
		$celkom += $pocet_kw;
		push @vysledky, $pocet_kw;	# ulozenie vysledkov
	}
}
#############################
# fcia na zratanie operatorov
# parametre vid. prep_k()
sub prep_o($$@)
{
	my $ec = @_[0];
	shift @_;
	my $pp = @_[0];
	shift @_;
	my @files = @_;
	my($i, $j, $pocet_o, $riadok, $otvor, $velkost);
	my $stav = 0;
	$velkost = scalar(@files);
	for $j (@files)
	{
		otvor_subor($velkost, $pp, $j, $ec);
		$pocet_o = 0;
		$stav = 1;
		while($riadok = <VSTUP>)
		{
			$riadok = &odstranit($riadok, $stav);
			$stav = 0;
			
			while($riadok =~ /[^\+\-&\*!~=\/%\|^\.<>][\+\-&\*!~=\/%\|^\.<>][^\+\-&\*!~=\/%\|^\.<>]/g)  # jeden znak
			{
				$pocet_o++;
			}
			while($riadok =~ /[^\+\-&\*!~=\/%\|^\.<>][\+\-\*\/^<>=!\|%&]=[^\+\-&\*!~=\/%\|^\.<>]/g)	# 2 znaky, jeden z toho =
			{
				$pocet_o++;
			}
			while($riadok =~ /[^\+\-&\*!~=\/%\|^\.<>](\+\+|\-\-|<<|>>|&&|\|\||\->|<<=|>>=)[^\+\-&\*!~=\/%\|^\.<>]/g)  # ostatne operatory
			{
				$pocet_o++;
				#print $1,"\n";
			}
			while($riadok =~ /[^\+\-&\*!~=\/%\|^\.<>](&\*|\*&)[^\+\-&\*!~=\/%\|^\.<>]/g)  # operatory & a * vedla seba
			{
				$pocet_o += 2;
			}
		}
		
		$celkom += $pocet_o;
		push @vysledky, $pocet_o;
	}
}
#############################
# fcia na spocitanie identifikatorov
# parametre vid. prep_k()
sub prep_i($$@)
{
	my @klucove_slova = qw(auto break case char const continue default do double else enum extern float for goto if int inline long
		      	       register return short signed sizeof static struct switch typedef union unsigned void volatile while);
	my $ec = @_[0];
	shift @_;
	my $pp = @_[0];
	shift @_;
	my @files = @_;
	my($i, $j, $pocet_i, $riadok, $velkost);
	my $stav = 0;
	$velkost = scalar(@files);
	for $j (@files)
	{
		otvor_subor($velkost, $pp, $j, $ec);
		$pocet_i = 0;
		$stav = 1;
		while($riadok = <VSTUP>)
		{
			$riadok = &odstranit($riadok, $stav);
			$stav = 0;
			for $i (@klucove_slova)		# odtranenie klucovych slov z riadku
			{
				$riadok =~ s/^$i([\s\*;:\(\[\{])/\1/g;
				while($riadok =~ s/([\(\s\{\}])$i([\s\*\)\(;:\[\{])/\1\2/g){;}
			}
			while($riadok =~ /([_a-zA-Z][\w]*)/g)
			{
				$pocet_i++ if(!($1 =~ /null|true|false/gi));
			}
		}
		$celkom += $pocet_i;	
		push @vysledky, $pocet_i;
	}
}
#############################
# fcia na spocitanie zadanych vzorov
# 4 parametre 1) chybovy kod pri neotvoreni suboru
#	      2) parameter -p
#	      3) vzor, aky sa ma v suboroch vyhladat
#	      4) pole suborov
sub prep_w($$$@)
{
	my $ec = @_[0];
	shift @_;
	my $pp = @_[0];
	shift @_;
	my $vzor = @_[0];
	shift @_;
	my @files = @_;
	my($i, $j, $pocet_w, $riadok, $velkost);
	my $od;		# zapameta si kde naslo posledny vzor a hlada od nasledujuceho znaku
	$velkost = scalar(@files);
	for $j (@files)
	{
		otvor_subor($velkost, $pp, $j, $ec);
		$pocet_w = 0;
		while($riadok = <VSTUP>)
		{
			$od = 0;
			while(1)
			{
				$od = index($riadok, $vzor, $od);	# fcia na vyhladavanie podretazcov v retazci
				if($od != -1)
				{
					$pocet_w++;
					$od++;
				}
				else
				{
					last;
				}
			}
		}
		
		$celkom += $pocet_w;
		push @vysledky, $pocet_w;
	}
}
#############################
# fcia a spocitanie znakov komentarov
# 2 parametre vid. prep_k()
# komentare sa rataju pri ich odstranovani zo suboru
# v tejto fcii sa len dane vysledky ulozia
sub prep_c($$@)
{
	my $ec = @_[0];
	shift @_;
	my $pp = @_[0];
	shift @_;
	my @files = @_;
	my($i, $j, $riadok, $velkost);
	my $stav = 0;
	$pocet_c = 0;
	$velkost = scalar(@files);
	
	for $j (@files)
	{
		otvor_subor($velkost, $pp, $j, $ec);
		$stav = 1;
		while($riadok = <VSTUP>)
		{
			$riadok = &odstranit($riadok, $stav);
			$stav = 0;
		}
		
		$celkom += $pocet_c;
		push @vysledky, $pocet_c;
		$pocet_c = 0;
	}
}
#############################

# premenne pre kontrolu paramerov a ich hodnotu
my($par_k, $par_o, $par_i, $par_w, $par_c, $par_p, $par_help, $par_input, $par_nosubdir, $par_output);
my $param;  # navratova hodnota fcie GetOptions

# inicializacia premennych zachytavajucich parametre
$par_k = $par_o = $par_i  = $par_c = $par_p = $par_help = $par_input = $par_nosubdir = $par_output = $param = -1;
$par_w = 93227;	# cislo 93227 je nahodne cislo, myslin, ze je mensia pravdepodobnost, ze niekto za toto ako -1 :)

# nacitanie parametrov
$param = GetOptions("help" => \$par_help,
		    "input=s" => \$par_input,
		    "nosubdir" => \$par_nosubdir,
		    "output=s" => \$par_output,
	   	    "k" => \$par_k,
	   	    "o" => \$par_o,
	   	    "i" => \$par_i,
		    "w=s" => \$par_w,
		    "c" => \$par_c,
		    "p" => \$par_p);

# kontrola, ci su spravne zadane parametre, resp. ci nie je zadany ziadny parameter naviac
if($param != 1)
{
	print STDERR "Nespravne zadane parametre, pouzi parameter --help pre napovedu\n";
	exit(1);
}

# program spusteny bez parametrov
if($par_help == -1 && 
   $par_input == -1 && $par_nosubdir == -1 && $par_output == -1 && $par_k == -1 && $par_o == -1 && $par_i == -1 && 
   $par_w == 93227 && $par_c == -1 && $par_p == -1)
{
	print STDERR "Nebol zadany ziadny parameter, pouzi parameter --help pre napovedu\n";
	exit(1);
}

# zadany parameter --help
if(($par_help == 1) && 
   ($par_input == -1 && $par_nosubdir == -1 && $par_output == -1 && $par_k == -1 && $par_o == -1 && $par_i == -1 && 
    $par_w == 93227 && $par_c == -1 && $par_p == -1))
{
	napoveda();
	exit(0);
}

# parameter --help nebol zadany samostatne, ukocenie s chybou
if(($par_help == 1) && 
   ($par_input != -1 || $par_nosubdir != -1 || $par_output != -1 || $par_k != -1 || $par_o != -1 || $par_i != -1 || 
    $par_w != 93227 || $par_c != -1 || $par_p != -1))
{
	print STDERR "Parameter help nesmie byt pouzity so ziadnym inym paramertom\n";
	exit(1);
}

# odstaranenie '=' z $par_w
if($par_w != 93227)
{
	substr($par_w, 0, 1, "");
}

# kontrola kratkych parametrov, nesmu sa kombinovat a ak nie je zadane --help, ocakava sa jeden z nich
if($par_k == -1 && $par_o == -1 && $par_i == -1 && $par_w == 93227 && $par_c == -1)
{
	print STDERR "Ocakavalo sa zadanie jedneho z parametrov -k, -o, -i, -w, -c,\n";
	print STDERR "pripadne kombinacia parametru -w s inym zo zadanych parametrov\n";
	exit(1);
}
elsif(($par_k + $par_o + $par_i + $par_c > -2 && $par_w == 93227) || ($par_k + $par_o + $par_i + $par_c > -3 && $par_w != 93227))
{
	print STDERR "Neopravnena kombinacia parametrov -k, -o, -i, -w, -c\n";
	exit(1);
}

my $otvor;	# premenna na navratovu hodnotu fcie open()
# otvorenie suboru na zapis vysledkov
if($par_output != -1)	# otvorenie vystupneho suboru
{
	$otvor = open(VYSTUP, ">$par_output");
	if($otvor != 1)
	{
		print STDERR "Nepodarilo sa otvorit vystupny subor\n";
		exit(3);
	}
}
else	# nebol zadany vystupny subor, vypisuje sa na STDOUT
{
	$otvor = open(VYSTUP, ">-");
	if($otvor != 1)
	{
		print STDERR "Nepodarilo sa otvorit vystupny subor\n";
		exit(3);
	}	
}

# sparacovanie vstupneho suboru alebo parametru
my $subor;	# premenne $subor urcuje ci sa jedna o subor (1, true), alebo o adresar (0, false)
if($par_input == -1)	# nezadany parameter, berie sa implicitne aktualny adresar
{
	$par_input = ".";
	$subor = 0;
}
elsif(-f $par_input)	# bol zadany konkretny subor
{
	$subor = 1;
}
elsif(-d $par_input)	# bol zadany adresar
{
	$subor = 0;
}
else	# bol zadany neexistujuci subor alebo adresar
{
	print STDERR "Zadany subor ci adresar neexistuje\n";
	exit(2);
}

# bol zadany subor aj parameter --nosubdir, co je zakazana kombinacia
if($subor == 1 && $par_nosubdir == 1)
{
	print STDERR "Parameter --nosubdir sa nesmie kombinovat s parametrom --input, ked je hodnota --input subor\n";
	exit(1);
}

my @vysl_s;	# pole so subormi s priponou .c a .h
my $i;		# riadiaca premenna
my $ec;		# chybovy kod pri otvoreni, je rozdielny ked je zadany jeden subor a ked je ich viac
if($subor == 1)	# je zadany jeden konkretny subor
{
	push @vysl_s, $par_input;
	$ec = 2;
}
elsif($subor == 0)	# je zadany adresar, hladaju sa vsetky subory
{
	$ec = 21;
	find({wanted => \&ziskaj_subory, preprocess => \&pre}, $par_input) if($par_nosubdir == 1);
	find(\&ziskaj_subory, $par_input) if ($par_nosubdir == -1);
	push @vysl_s, grep /.*\.[ch]/, @subory;	# vyfiltrovanie suborov s priponou .c a .h

}
#############################
my($v, $vi, $pocet_cifier, @nove_pole);
$v = scalar(@vysl_s);
@s_cestou = @vysl_s;
if($par_p == 1)			# ak je zadany parameter -p, ulozi si subory bez relativnej cesty a zoradi
{
	for($vi = 0; $vi < $v; $vi++)
	{
		@vysl_s[$vi] =~ s/.*\/([^\/]+)/\1/g;
	}
	@vysl_s = sort @vysl_s;
}
############################
# hlavna cast, ratanie danych udajov
prep_k($ec, $par_p, @vysl_s) if($par_k == 1);
prep_o($ec, $par_p, @vysl_s) if($par_o == 1);
prep_i($ec, $par_p, @vysl_s) if($par_i == 1);
prep_w($ec, $par_p, $par_w, @vysl_s) if($par_w != 93227);
prep_c($ec, $par_p, @vysl_s) if($par_c == 1);

my $dlzka = -1;		# velkost najdlsieho mena suboru 
my $najc -1;		# najvacsie cislo (pocet vyskyto), najvacsie cislo je zakonite najviac cifier

###########################
if($par_p != 1)  # parameter -p nebol zadany, subory sa vypisu s absolutnou cestou
{
	for($vi = 0; $vi < $v; $vi++)
	{
		@vysl_s[$vi] = abs_path(@vysl_s[$vi]);
		
	}
}
##################################

for $v (@vysl_s)	# zistenie dlzky najdlsieho nazvu
{
	$dlzka = length($v) if(length($v) > $dlzka);
}

$dlzka = length("CELKEM:") if(length("CELKEM:") > $dlzka); # najdlhsi nazov nemusi byt dlhsi ako CELKEM:

$najc = $celkom if($celkom > $najc);	# sucet vsetkychvyskytov je pravdepodobne vacsi ako jednotlive vyskyty

while($najc > 0)	# zistenie poctu cifier
{
	$najc = int($najc / 10);
	$pocet_cifier++;
}

for $v (@vysl_s)	# vypis hodnot, printf - formatovany vypis
{
	printf VYSTUP ("%-*s", $dlzka, $v);	# mena suborov
	printf VYSTUP (" %*d\n", $pocet_cifier, @vysledky[0]);	# hodnoty
	shift @vysledky;
}
# vysledny sucet
printf VYSTUP ("%-*s", $dlzka, "CELKEM:");
printf VYSTUP (" %*d\n", $pocet_cifier, $celkom);

close(VYSTUP);
close(VSTUP);
exit(0);

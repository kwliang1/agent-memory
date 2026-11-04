#!/usr/bin/perl
# Prints the CATALOG.md lines a prompt is about, best first, as "<scope dir>\t<line>".
#
# Usage: catalog-match.pl <scope dir>...   (prompt on stdin)
#   CATALOG_SEEN       file of lines already injected this session; they are skipped
#   CATALOG_PARTIAL    scope dirs, one per line, whose MEMORY.md reached the session only in part
#   CATALOG_MAX_LINES  how many lines at most (default 6)
#   CATALOG_MIN        the score a line needs (default 1.5)
#
# A word or number scores only where it names a memory -- its link title, its filename, or
# the bold label of its group -- and only as much as it is rare in that scope's catalog. One
# rare word alone is not enough: measured on 70 of Kevin's prompts, single words like
# "create" or "session" fired on 31 of them, almost all wrong.
use strict;
use warnings;

my $max = $ENV{CATALOG_MAX_LINES} // 6;
my $min = $ENV{CATALOG_MIN} // 1.5;
my %stop = map { $_ => 1 } qw(
  about after again also because been before being both cannot check claude could does
  doing done each even every from going good have help here into just kevin know like
  look made make many memory memories more most much need only other over please really
  right same said says session should show some still such sure tell than thanks that
  their them then there these they thing things think this those through under used
  using want were what when where which while will with without work would yeah your
  add all and any are ask but can did end few for get got had has her his how its let lmk
  lot may new not now off one our out per pls put say see set the too try two use via was
  way who why yes you ci id ok pr
  an as at be by do don if in is it no of on or so to up we
);

# A prompt word scores as itself or as the sum of its parts, whichever is more: "merge-ref" never counts thrice.
my $raw = do { local $/; <STDIN> // '' };
my (%group, %short);
for my $w (lc($raw) =~ /[a-z0-9][a-z0-9_.-]*[a-z0-9]/g) {
  for my $t ($w, split /[-_.]/, $w) {
    next if $stop{$t} || length $t < 2;
    next if $t ne $w && $t =~ /^\d{4}$/ && $w =~ /(?<!\d)$t-\d\d-\d\d/;
    $t =~ s/(?<=[^s])s$// if length $t > 5;
    $short{$t} = 1 if length $t < 4 && $t !~ /\d{3}/;
    $group{$t} //= $w;
  }
}
exit 0 unless %group;

my %partial = map { $_ => 1 } split /\n/, $ENV{CATALOG_PARTIAL} // '';
my %seen;
if (my $f = $ENV{CATALOG_SEEN}) {
  if (open my $fh, '<', $f) { while (<$fh>) { chomp; $seen{$_} = 1 } }
}

my @lines;
for my $dir (@ARGV) {
  open my $cat, '<', "$dir/CATALOG.md" or next;
  my %hot;
  if (!$partial{$dir} && open my $idx, '<', "$dir/MEMORY.md") {
    while (<$idx>) { $hot{$1} = 1 while /\]\(([^)]+\.md)\)/g }
  }
  while (my $line = <$cat>) {
    chomp $line;
    next unless $line =~ /^- /;
    my ($label) = $line =~ /^- \*\*([^*]+)\*\*/;
    my (@names, @fresh);
    while ($line =~ /\[([^\]]+)\]\(([^)]+\.md)\)/g) {
      push @names, lc "$1 $2";
      push @fresh, $2 unless $hot{$2};
    }
    next unless @names;
    push @names, lc $label if defined $label;
    push @lines, { dir => $dir, text => $line, lc => lc $line, names => \@names,
                   skip => $seen{$line} || !@fresh };
  }
}

# Acronyms like ACH, TP or MMF name many memories, and Kevin types them in either case, so a
# two- or three-letter word counts when some memory's name uses it as a whole word.
my %named;
for my $l (@lines) { for (@{ $l->{names} }) { $named{$1} = 1 while /(?<![a-z0-9])([a-z0-9]{2,3})(?![a-z0-9])/g } }
delete $named{$_} for grep { !/[a-z]/ } keys %named;
delete $group{$_} for grep { !$named{$_} } keys %short;

my (%df, %hits);
for my $t (keys %group) {
  my $re = $t =~ /\d{4}/  ? qr/(?<![0-9,])\Q$t\E(?![0-9,])/
         : length $t < 4  ? qr/(?<![a-z0-9])\Q$t\E(?![a-z0-9])/
         :                  qr/(?<![a-z0-9])\Q$t\E/;
  for my $i (0 .. $#lines) {
    next unless $lines[$i]{lc} =~ $re;
    $df{ $lines[$i]{dir} }{$t}++;
    push @{ $hits{$i} }, [$t, $re];
  }
}

my @picked;
for my $i (sort { $a <=> $b } keys %hits) {
  my $l = $lines[$i];
  next if $l->{skip};
  my $best = 0;
  for my $name (@{ $l->{names} }) {
    my (%whole, %parts);
    for my $h (@{ $hits{$i} }) {
      my ($t, $re) = @$h;
      next unless $name =~ $re;
      my $df = $df{ $l->{dir} }{$t};
      my $w = ($t =~ /\d{4}/ ? 2 : 1) * ($df <= 3 ? 1 : $df <= 8 ? 0.5 : 0);
      if ($t eq $group{$t}) { $whole{$t} = $w } else { $parts{ $group{$t} } += $w }
    }
    my $score = 0;
    for my $g (keys %{{ %whole, %parts }}) {
      my ($wh, $pt) = ($whole{$g} // 0, $parts{$g} // 0);
      $score += $wh > $pt ? $wh : $pt;
    }
    $best = $score if $score > $best;
  }
  push @picked, { %$l, score => $best, order => $i } if $best >= $min;
}

@picked = sort { $b->{score} <=> $a->{score} || $a->{order} <=> $b->{order} } @picked;
splice @picked, $max if @picked > $max;
print $ENV{CATALOG_DEBUG} ? "$_->{score}\t" : '', "$_->{dir}\t$_->{text}\n" for @picked;

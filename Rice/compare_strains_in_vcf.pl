#!/usr/bin/perl -w
use strict;
use Data::Dumper;
## 

# 

=head1 NAME

compare_strains_in_vcf - compare strain SNPs from a VCF to count Het and homozygous positions

=head1 SYNOPSIS

compare_strains_in_vcf.pl out.tab

# run 'cat file.vcf | vcf-to-tab > out.tab' before running this script

=head1 DESCRIPTION

This script provides comparison of SNP positions from a VCF tab file

=head1 AUTHOR

Sofia Robb <sofia.robb[AT]ucr.edu>

=cut

my $vcf_tab = shift;

if ( !defined $vcf_tab ) {
  die "need a VCF file that has been convererted to a TAB.

  run 'cat file.vcf | vcf-to-tab > out.tab' before running this script

 ./compare_strains_in_vcf.pl out.tab

";
}

open(VCFTAB, "$vcf_tab") or die "Can't open VCF Tab file $vcf_tab\n";

#expected input look like this

##CHROM  POS     REF     EG4_2   HEG4_2
#Chr1    1117    A       A/A     A/C
chomp( my $header = <VCFTAB> );
my @header = split /\t/, $header;
shift @header;
shift @header;
shift @header;
my @strains      = @header;
my $strain_count = @strains;
my %SNPs;
my %ref;
my %binary;

while ( my $line = <VCFTAB> ) {
  chomp $line;
  ##if you do not want to use any line without all strains having full data use next line
  next if $line =~ /\.\/\./;      #skip whole line if ./.
  next if $line =~ /threw out/;

  ##if you do not want any lines with a het
  ##skip the line if there is a het
  #next if $line !~ /(.)\/\1/g;

  my ( $chr, $pos, $ref_nt, @snp ) = split /\t/, $line;
  for ( my $i = 0 ; $i < $strain_count ; $i++ ) {
    $SNPs{"$chr.$pos"}{ $header[$i] } = $snp[$i];
    $ref{"$chr.$pos"} = $ref_nt;
    for ( my $i = 0 ; $i < @snp ; $i++ ) {
      my ( $a1, $a2 ) = $snp[$i] =~ /(.)\/(.)/;

      #every het position wil be diff from ref
      if ( $a1 ne $a2 ) {
        $binary{"$chr.$pos"}{ $strains[$i] } = 2;    ##hets ok, note as 2
      }

      #not enough data
      elsif ( $a1 eq '.' ) {    ##no 9 , count as same as ref
        $binary{"$chr.$pos"}{ $strains[$i] } = 9;
      }

      #homozygous position that is diff from ref
      elsif ( ( $a1 eq $a2 ) and ( $ref_nt ne $a2 ) ) {
        $binary{"$chr.$pos"}{ $strains[$i] } = 1;
      }

      #homozygouos position that is same as ref
      elsif ( ( $a1 eq $a2 ) and ( $ref_nt eq $a2 ) ) {
        $binary{"$chr.$pos"}{ $strains[$i] } = 0;
      }
    }
  }
}

my %uniqHomo;
my %uniqHomLoc;
my %uniqHet;
my %mixed;
my $unq_hets;
my %total_hom;
my $total_shared_hom;
foreach my $loc ( sort keys %binary ) {
  my @strains = keys %{ $binary{$loc} };
  my @codes;
  ##0=same as ref
  ##1=homo diff from ref
  ##2=het
  ##9=not enough data ./.
  foreach my $strain (@strains) {

    #foreach my $strain (keys %{$binary{$loc}}){
    my $code = $binary{$loc}{$strain};
    push @codes, $code;
  }
  my $codes = join '', @codes;
  my $no_snp_count             = $codes =~ tr/0/0/;
  my $homo_diff_from_ref_count = $codes =~ tr/1/1/;
  my $hets_count               = $codes =~ tr/2/2/;
  my $missing_data_count       = $codes =~ tr/9/9/;

  ## for total homo snps in each strain
  ## if all strains are a 1 or a zero, then if it is a 1 add up its total hom count;
  if (  $hets_count == 0
    and $missing_data_count == 0
    and $homo_diff_from_ref_count > 0 )
  {
    for ( my $i = 0 ; $i < @codes ; $i++ ) {
      my $code = $codes[$i];
      if ( $code == 1 ) {
        $total_hom{ $strains[$i] }++;
      }
    }
  }
  ## for total shared homo snps
  ## if all strains are a 1, then if it is a 1 add up its total shared hom count;
  if (  $hets_count == 0
    and $missing_data_count == 0
    and $homo_diff_from_ref_count == scalar @strains )
  {
    $total_shared_hom++;
  }

  ## uniq homozygous snps
  ## if found only 1 homo diff from ref --> uniq homo snp
  if (  $homo_diff_from_ref_count == 1
    and $hets_count == 0
    and $missing_data_count == 0 )
  {
    for ( my $i = 0 ; $i < @codes ; $i++ ) {
      my $code = $codes[$i];
      if ( $code == 1 ) {
        $uniqHomo{ $strains[$i] }++;
      }
    }
    ## for each strain at a uniq Hom Loc, keep note of all nts
    foreach my $strain (@strains) {
      $uniqHomLoc{$loc}{$strain} = $SNPs{$loc}{$strain};
    }
    $uniqHomLoc{$loc}{ref} = $ref{$loc};
  }
  ## if found only 1 het diff from ref --> uniq het snp
  if (  $homo_diff_from_ref_count == 0
    and $hets_count == 1
    and $missing_data_count == 0 )
  {
    for ( my $i = 0 ; $i < @codes ; $i++ ) {
      my $code = $codes[$i];
      if ( $code == 2 ) {
        $uniqHet{ $strains[$i] }++;
        my @snps_at_loc;
        my @strains = sort keys %{ $SNPs{$loc} };
        foreach my $strain (@strains) {
          push @snps_at_loc, $SNPs{$loc}{$strain};
        }
        my $snps_at_loc = join ',', @snps_at_loc;
        my $strains     = join ',', @strains;
        $unq_hets .= "$loc\tref=$ref{$loc}\t$strains\t$snps_at_loc\n";
      }
    }
  }
  ## 2 strains both have SNPs, one HOMO, one HETE. could be Ref=T A/A,A/T. all other strains need to be 0
  if (  $homo_diff_from_ref_count == 1
    and $hets_count == 1
    and $missing_data_count == 0 )
  {
    for ( my $i = 0 ; $i < @codes ; $i++ ) {
      my $code = $codes[$i];
      $mixed{$loc}{ $strains[$i] } = $code;
    }
  }
}
print
"\n\ncount of total HOMO SNPs. Ref=T A/A,T/T is counted. Ref=T A/A,A/T is not counted for either strain:\n";
foreach my $strain ( keys %total_hom ) {
  my $count = $total_hom{$strain};
  print "$strain\t$count\n";
}
print
"\n\ncount of unique HOMO SNPs. Ref=T A/A,T/T is counted. Ref=T A/A,A/T is not counted for either strain:\n";
foreach my $strain ( keys %uniqHomo ) {
  my $count = $uniqHomo{$strain};
  print "$strain\t$count\n";
}
print
"\n\ncount of shared HOMO SNPs. Ref=T T/T,T/T is counted. Ref=T A/A,A/T is not counted for either strain:\n";
print "@strains\t$total_shared_hom\n";

if ( ( scalar( keys %uniqHet ) ) > 1 ) {
  print
"\n\ncount of unique HET SNPs. Ref=T T/T,A/T is counted. Ref=T A/A,A/T is not counted for either strain:\n";
  foreach my $strain ( keys %uniqHet ) {
    my $count = $uniqHet{$strain};
    print "$strain\t$count\n";
  }
}

print "\n**Locations unique HOMO SNPs.\n";
print "loc\tref\t", join "\t", @strains, "\n";
foreach my $loc ( sort keys %uniqHomLoc ) {
  my $ref = $uniqHomLoc{$loc}{ref};
  print "$loc\t$ref\t";
  for ( my $i = 0 ; $i < ( ( scalar @strains ) - 1 ) ; $i++ ) {
    my $strain = $strains[$i];
    my $nt     = $uniqHomLoc{$loc}{$strain};
    print "$nt\t";
  }
  my $last_strain = $strains[-1];
  my $nt          = $uniqHomLoc{$loc}{$last_strain};
  print "$nt\n";
}

if ( defined $unq_hets ) {
  print "\n**Locations unique HET SNPs.\n";
  print "$unq_hets\n\n";
}

if ( scalar keys %mixed > 0 ) {
  print
"\n\n**count of locations with  2 strains with SNPs, one HOM one HET SNPs. Ref=T A/A,A/T is counted. Ref=T T/T,A/T is not counted for either strain:\n";
  my $mixed_count = 0;
  my %mixed_strains;
  foreach my $loc ( keys %mixed ) {
    my @mixed_strains;
    $mixed_count++;
    foreach my $strain ( keys %{ $mixed{$loc} } ) {
      my $code = $mixed{$loc}{$strain};
      if ( $code == 1 or $code == 2 ) {
        push @mixed_strains, $strain;
      }
    }
    my @sorted = sort @mixed_strains;
    my $strains = join ',', @sorted;
    $mixed_strains{$strains}++;
  }
  foreach my $strains ( keys %mixed_strains ) {
    my $count = $mixed_strains{$strains};
    print "$strains\t$count\n";
  }
  print "$mixed_count\n";
}

#!/usr/bin/perl

use v5.24;

use strict;
use warnings;

use Encode;
use Mojo::Date;
use Mojo::File qw(curfile);
use Mojo::UserAgent;
use Mojo::Template;
use Time::Piece;
use XML::RSS;

my $home = curfile->dirname;

my $ua  = Mojo::UserAgent->new;
my $now = localtime;

my $current_year = $now->year;

my @news_items;

YEAR:
for my $year ( reverse $current_year-2 .. $current_year+1 ) {
    my $base = 'http://act.yapc.eu/gpw' . $year;
    my $tx   = $ua->get( $base . '/news');

    if ( my $err = $tx->error ) {
        print sprintf "ERROR: Cannot get news for %s: %s (%s)! ", $year, $err->{message}, $err->{code};
        next YEAR;
    }

    my $heads = $tx->res->dom->find(".newsbox>h3");

    $heads->each( sub {
        my $title_node = $_->find('a')->first;
        my $title      = $title_node->text;
        my $link       = $title_node->attr('href');

        $link =~ s{^/}{$base/};

        my $date_author = $_->next;
        my ($d,$m,$y)   = $date_author->content =~ m{([0-9]+)/([0-9]+)/([0-9]+)};
        my $author      = $date_author->find('em>a')->first->text;

        my $text = '';
        my $next = $date_author->next;
        while ( $next && $next->tag ne 'h3' && $next->tag ne 'div' ) {
            $text .= '<p>' . $next->content . '</p>';
            $next  = $next->next;
        }

        push @news_items, {
            title  => $title,
            day    => $d,
            month  => $m,
            year   => $y,
            author => $author,
            text   => $text,
            link   => $link,
            date   => ( sprintf "%02d.%02d.20%02d", $d, $m, $y ),
        };
    });
}

@news_items = @news_items[ 0 .. ( $#news_items > 9 ? 9 : $#news_items ) ];

my $rss = XML::RSS->new( version => '2.0' );
$rss->channel(
    title          => 'German Perl-/Raku-Workshop',
    link           => 'https://german-perl-workshop.de',
    language       => 'de',
    description    => 'German Perl-/Raku-Workshop',
    copyright      => "Copyright $current_year, Frankfurt Perlmonger e.V.",
    pubDate        => Mojo::Date->new->to_string,
    managingEditor => 'info@german-perl-workshop.de',
    webMaster      => 'info@german-perl-workshop.de',
);

for my $item ( @news_items ) {
    $rss->add_item(
        title       => $item->{title},
        permaLink   => $item->{link},
        description => $item->{abstract},
        pubDate     => $item->{published},
    );
}

$home->child('public', 'news.rss')->spurt( $rss->as_string );

my $tmpl = Mojo::Template->new->vars(1);
my $html = $tmpl->render_file(
    $home->child('templates', 'news.html.ep'),
    {
        news => \@news_items,
    }
);

$html = encode_utf8( $html );

$home->child('static', 'news.html')->spurt( $html );

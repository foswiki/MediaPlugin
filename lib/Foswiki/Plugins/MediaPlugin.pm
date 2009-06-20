# MediaPlugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) TWiki:Main.PiersGoodhew SvenDowideit@fosiki.com arthur@visiblearea.com and Foswiki Contributors.

=pod

---+ package MediaPlugin

=cut

# change the package name and $pluginName!!!
package Foswiki::Plugins::MediaPlugin;

use Error qw( :try );

# Always use strict to enforce variable scoping
use strict;

my $VERSION = '$Rev$';
my $RELEASE = '1.3.2';

my $debug   = 0;
my $installWeb;
my $pluginName = 'MediaPlugin';

# plugin global settings
my $PLUGIN_SETTING_WIDTH;
my $PLUGIN_SETTING_HEIGHT;
my $PLUGIN_SETTING_SHOW_CONTROLLER;
my $PLUGIN_SETTING_AUTOPLAY;

my $MIMETYPES; # filled by parsing mimetypes.txt, when necessary
our $NO_PREFS_IN_TOPIC = 1;

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my ( $inTopic, $inWeb, $inUser, $inInstallWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

	$installWeb = $inInstallWeb;
	
    #TODO: these should be moved into Config.spec for performance.
    $PLUGIN_SETTING_HEIGHT =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_HEIGHT") || 180;
    $PLUGIN_SETTING_WIDTH =
      Foswiki::Func::getPreferencesValue("\U$pluginName\E_WIDTH") || 320;
    $PLUGIN_SETTING_SHOW_CONTROLLER =
      lc( Foswiki::Func::getPreferencesValue("\U$pluginName\E_CONTROLLER") ) || 'true';
    $PLUGIN_SETTING_AUTOPLAY =
      lc( Foswiki::Func::getPreferencesValue("\U$pluginName\E_PLAY") ) || 'true';

    $debug =
      Foswiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG" );

    # register the OBJECT function to handle %MEDIA{...}%
    Foswiki::Func::registerTagHandler( 'MEDIA', \&_MEDIA );

    # support old syntax:
    Foswiki::Func::registerTagHandler( 'OBJECT', \&_MEDIA );

    # Plugin correctly initialized
    return 1;
}

=pod

---++ _MEDIA( $session, $params, $topic, $web ) -> $html

Handle MEDIA tag.

=cut

sub _MEDIA {
    my ( $this, $inParams, $inTopic, $inWeb ) = @_;

    # get media format
    my $source =
         $inParams->{_DEFAULT}
      || $inParams->{src}
      || $inParams->{data}
      || $inParams->{filename};
    my ( $fileHeader, $extension ) = ( $source =~ /(.*)\.+(.*$)/i );
	$extension = lc($extension);
    $extension = 'swf' if ( $source =~ m/youtube.com/i );

    return _handleEmbedSwf( $source, $extension, @_ ) if $extension eq 'swf';
    return _handleEmbedMov( $source, $extension, @_ ) if $extension eq 'mov';
    return _handleEmbedWmv( $source, $extension, @_ ) if $extension eq 'wmv';

    # generic formats:
    return _handleEmbedGeneric( $source, $extension, @_ );
}

=pod

---++ _handleEmbedMov( $source, $session, $params, $topic, $web ) -> $html

Calls _createHtml with type 'mov'.

=cut

sub _handleEmbedMov {
    my ( $inSource, $inExtension, $this, $inParams, $inTopic, $inWeb ) = @_;

    # QuickTime specific params
    my $localParams = $inParams;
    $localParams->{'controller'} ||= $PLUGIN_SETTING_SHOW_CONTROLLER;
    $localParams->{'height'} += 16 if $localParams->{'controller'};
    $localParams->{'autoplay'} ||= $localParams->{'play'} ||=
      lc($PLUGIN_SETTING_AUTOPLAY);
    delete $localParams->{'play'};

    return _createHtml( $inSource, $localParams, 'mov' );
}

=pod

---++ _handleEmbedWmv( $source, $session, $params, $topic, $web ) -> $html

Calls _createHtml with type 'wmv'.

=cut

sub _handleEmbedWmv {
    my ( $inSource, $inExtension, $this, $inParams, $inTopic, $inWeb ) = @_;

    # WMV specific params
    my $localParams = $inParams;
    $localParams->{'ShowControls'} ||= $localParams->{'controller'} ||=
      $PLUGIN_SETTING_SHOW_CONTROLLER;
    delete $localParams->{'controller'};
    $localParams->{'height'} += 46 if $localParams->{'ShowControls'};
    $localParams->{'autostart'} ||= $localParams->{'play'} ||=
      lc($PLUGIN_SETTING_AUTOPLAY);
    delete $localParams->{'play'};

    return _createHtml( $inSource, $localParams, 'wmv' );
}

=pod

---++ _handleEmbedSwf( $source, $session, $params, $topic, $web ) -> $html

Calls _createHtml with type 'swf'.

See [[http://kb.adobe.com/selfservice/viewContent.do?externalId=tn_12701][Flash OBJECT and EMBED tag attributes]].

=cut

sub _handleEmbedSwf {
    my ( $inSource, $inExtension, $this, $inParams, $inTopic, $inWeb ) = @_;

    return _createHtml( $inSource, $inParams, 'swf' );
}

=pod

---++ _handleEmbedGeneric( $source, $session, $params, $topic, $web ) -> $html

Embeds generic media formats such as 'html'. See [[http://www.w3.org/TR/REC-html40/struct/objects.html][Objects, Images, and Applets]].

Calls _createHtml with type 'generic'.

=cut

sub _handleEmbedGeneric {
    my ( $inSource, $inExtension, $this, $inParams, $inTopic, $inWeb ) = @_;

    my $localParams = $inParams;
    $localParams->{'data'} ||= $inSource;
    
    # we are not sure which plugin will play (possible) audio/video
    # so we add both - only if param 'play' is passed explicitly
    # (otherwise we set autostart to jpeg files which is a bit silly)
    $localParams->{'autostart'} ||= $localParams->{'play'} if $localParams->{'play'};
    $localParams->{'autoplay'} ||= $localParams->{'play'} if $localParams->{'play'};
      
    delete $localParams->{'src'};
    delete $localParams->{'_DEFAULT'};

	# add mimetype if not passed
	if (!$localParams->{'type'}) {
		_createMimeTypeTable($this) if !defined $MIMETYPES;
		$localParams->{'type'} ||= $MIMETYPES->{$inExtension} if defined $MIMETYPES;
	}
    return _createHtml( undef, $localParams, 'generic' );
}

=pod

---++ _createHtml( $source, $params, $type ) -> $html

Reads in type specific template and substitutes attribute placeholders.

=cut

sub _createHtml {
    my ( $inSource, $inParams, $inType ) = @_;

    my $type = $inType || '';
    my $PATTERN_SPLIT = '\s*,\s*';

    my $templateName = _getTemplateName($type);
    Foswiki::Func::loadTemplate($templateName);

    my $txt_default_attributes =
      Foswiki::Func::expandTemplate('syntax:default_attributes');
    my %default_attributes =
      Foswiki::Func::extractParameters($txt_default_attributes);
    delete $default_attributes{_RAW};
    delete $default_attributes{_DEFAULT};

    if ($debug) {
        use Data::Dumper;
        Foswiki::Func::writeDebug(
"MediaPlugin::_createHtml; default_attributes read from template '$templateName':"
              . Dumper(%default_attributes) );
    }

    my $localParams;
    if (%default_attributes) {
        $localParams = _mergeHashes( $inParams, \%default_attributes );
    }
    else {
        $localParams = $inParams;
    }

    # set default values
    $localParams->{'src'} = $inSource if $inSource;
    $localParams->{'width'}  ||= $PLUGIN_SETTING_WIDTH;
    $localParams->{'height'} ||= $PLUGIN_SETTING_HEIGHT;

    if ($debug) {
        use Data::Dumper;
        Foswiki::Func::writeDebug(
            "MediaPlugin::_createHtml; type=$type; localParams="
              . Dumper($localParams) );
    }

    my $txt_object_only_attributes =
      Foswiki::Func::expandTemplate('syntax:object_only_attributes');
    _trimSpaces($txt_object_only_attributes);
    my $txt_embed_only_attributes =
      Foswiki::Func::expandTemplate('syntax:embed_only_attributes');
    _trimSpaces($txt_embed_only_attributes);
    my $txt_object_attributes =
      Foswiki::Func::expandTemplate('syntax:object_attributes');
    _trimSpaces($txt_object_attributes);

    my %object_only_attributes =
      map { $_ => 1 }
      split( $PATTERN_SPLIT, $txt_object_only_attributes )
      if $txt_object_only_attributes;
    my %embed_only_attributes =
      map { $_ => 1 }
      split( $PATTERN_SPLIT, $txt_embed_only_attributes )
      if $txt_embed_only_attributes;
    my %object_attributes =
      map { $_ => 1 }
      split( $PATTERN_SPLIT, $txt_object_attributes )
      if $txt_object_attributes;

    # load text from template, then replace placeholders
    my $text = Foswiki::Func::expandTemplate('object');

    # sort params for easier testing and debugging
    foreach my $key ( sort keys %$localParams ) {

        # do not use attributes starting with an underscore
        next if $key =~ m/^_.*?$/;

        my $value = $localParams->{$key};

		if ($debug) {
			$key ||= '';
			$value ||= '';
		}
        Foswiki::Func::writeDebug(
            "MediaPlugin::_createHtml; key=$key;value=$value")
          if $debug;

        if ( $object_only_attributes{$key} ) {
            $text =~ s/({MP_OBJECT_ATTRIBUTES})/ $key="$value"$1/go;
            next;
        }
        if ( $embed_only_attributes{$key} ) {
            $text =~ s/({MP_EMBED_ATTRIBUTES})/ $key="$value"$1/go;
            next;
        }
        if ( $object_attributes{$key} ) {
            $text =~ s/({MP_OBJECT_ATTRIBUTES})/ $key="$value"$1/go;
        }
        else {
            $text =~
              s/({MP_OBJECT_PARAMS})/<param name="$key" value="$value" \/>$1/go;
        }
        $text =~ s/({MP_EMBED_ATTRIBUTES})/ $key="$value"$1/go;
    }

    # clean up placeholders, no longer needed
    $text =~ s/{MP_OBJECT_ATTRIBUTES}//go;
    $text =~ s/{MP_OBJECT_PARAMS}//go;
    $text =~ s/{MP_EMBED_ATTRIBUTES}//go;

    return "<noautolink>$text</noautolink>";
}

=pod

---++ _getTemplateName ( $type ) -> $text

Gets the name of a type specific template. For instance: type 'swf' gets template 'mediaplugin_swf'.

=cut

sub _getTemplateName {
    my ( $inType, $inModule ) = @_;

    my $templateName = 'mediaplugin';
    $templateName .= "_$inType" if $inType && $inType ne 'generic';
    return $templateName;
}

=pod

Creates mimetype tabe $MIMETYPES from reading and parsing attachment 'mimetypes.txt.

=cut

sub _createMimeTypeTable {
    my ( $this ) = @_;

	my $topicObject = Foswiki::Meta->new( $this, $installWeb, $pluginName );
	my $typesStream = $topicObject->openAttachment( 'mimetypes.txt', '<' );
	
	_debug("\t opened stream=$typesStream");

	local $/ = undef;
	%{ $MIMETYPES } = split( /\s+/, <$typesStream> );
	$typesStream->close();
	
	catch Error::Simple with {
		%{ $MIMETYPES } = ();
	};
	if ($debug) {
		use Data::Dumper;
		Foswiki::Func::writeDebug("MediaPlugin::_createMimeTypeTable; MIMETYPES=" . (keys %{ $MIMETYPES }) . " keys");
	}
}

=pod

mergeHashes (\%a, \%b ) -> \%merged

Merges 2 hash references.

=cut

sub _mergeHashes {
    my ( $A, $B ) = @_;

    my %merged = ();
    while ( my ( $k, $v ) = each(%$A) ) {
        $merged{$k} = $v;
    }
    while ( my ( $k, $v ) = each(%$B) ) {
        $merged{$k} = $v;
    }
    return \%merged;
}

=pod

trimSpaces( $text ) -> $text

Removes spaces from both sides of the text.

=cut

sub _trimSpaces {

    #my $text = $_[0]

    $_[0] =~ s/^[[:space:]]+//s;    # trim at start
    $_[0] =~ s/[[:space:]]+$//s;    # trim at end
}

=pod

=cut

sub _debug {
    my ($inText) = @_;

    Foswiki::Func::writeDebug($inText)
      if $Foswiki::Plugins::MediaPlugin::debug;
}

1;

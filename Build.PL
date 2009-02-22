use Module::Build;
Module::Build->new
(
	'module_name' => 'POE::Filter::XML',
	'license' => 'gpl',
	'create_readme' => 1,
	'requires' =>
	{
		'perl'	=>	'5.10.0',
		'POE'	=>	'1.003',
		'XML::SAX' => '0.16',
		'Filter::Template' => '1.02',
        'Class::InsideOut' => '1.09',
        'XML::LibXML' => '1.69',
	}
)->create_build_script();

newoption {
	trigger = "mbedtls-src",
	description = "Change mbedTLS source directory",
	default = path.join(path.getdirectory(_SCRIPT), "../contrib/mbedtls"),
	value = "path|none"
}

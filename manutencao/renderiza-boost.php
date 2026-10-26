<?php

// Renderiza as skills .blade.php do Boost sem instalar o Boost: Blade do vendor + um GuidelineAssist falso.
// Uso: php renderiza-boost.php <vendor/autoload.php> <origem> <destino> <pest|phpunit>

require $argv[1];

use Illuminate\Filesystem\Filesystem;
use Illuminate\View\Compilers\BladeCompiler;

[, , $origem, $destino, $variante] = $argv;
$pest = $variante === 'pest';

$assist = new class($pest)
{
    public object $project;

    public function __construct(private bool $pest)
    {
        $this->project = new class
        {
            public function php(): object
            {
                return new class
                {
                    public function package(string $nome): ?object
                    {
                        return null;
                    }
                };
            }
        };
    }

    public function hasPackage(string $nome, ?string $restricao = null): bool
    {
        return $this->pest && $nome === 'pestphp/pest';
    }

    public function artisanCommand(string $comando): string
    {
        return "php artisan {$comando}";
    }

    public function composerCommand(string $comando): string
    {
        return "composer {$comando}";
    }

    public function binCommand(string $comando): string
    {
        return "vendor/bin/{$comando}";
    }
};

// Mesmo pipeline de Laravel\Boost\Concerns\RendersBladeGuidelines::renderContent (v2.10.3).
function renderiza(string $content, BladeCompiler $blade, object $assist): string
{
    $placeholders = [
        '`' => '___SINGLE_BACKTICK___',
        '<?php' => '___OPEN_PHP_TAG___',
        '@volt' => '___VOLT_DIRECTIVE___',
        '@endvolt' => '___ENDVOLT_DIRECTIVE___',
        '@can' => '___CAN_DIRECTIVE___',
        '@include' => '___INCLUDE_DIRECTIVE___',
        '@props' => '___PROPS_DIRECTIVE___',
        '</x-' => '___BLADE_COMPONENT_CLOSE___',
        '<x-' => '___BLADE_COMPONENT_OPEN___',
    ];

    $escapes = [];
    $skipVerbatim = '@verbatim.*?@endverbatim(*SKIP)(*FAIL)|';
    $bounded = '(?:(?!\n[ \t]*\n|\n[ \t]*`{3,}|\n[ \t]*~{3,}).)*?';
    foreach ([
        '/'.$skipVerbatim.'(?<!@)@\{!!'.$bounded.'!!\}/s',
        '/'.$skipVerbatim.'(?<!@)@\{\{'.$bounded.'\}\}/s',
        '/'.$skipVerbatim.'(?<!@)@(?:\{!!|\{\{)/s',
        '/'.$skipVerbatim.'(?<![\w@])@@(?=\w)/s',
    ] as $pattern) {
        $content = preg_replace_callback($pattern, function (array $m) use (&$escapes): string {
            $placeholder = '___BLADE_ESCAPE_'.count($escapes).'___';
            $escapes[$placeholder] = substr($m[0], 1);

            return $placeholder;
        }, $content) ?? $content;
    }

    $content = preg_replace_callback(
        '/(?<fence>`{3,}|~{3,}).*?\k<fence>/s',
        fn (array $m): string => str_replace('&', '___AMPERSAND___', $m[0]),
        $content,
    ) ?? $content;
    $content = str_replace(array_keys($placeholders), array_values($placeholders), $content);

    $codigo = $blade->compileString($content);
    $rendered = (static function (string $__codigo, object $assist): string {
        ob_start();
        eval('?>'.$__codigo);

        return ob_get_clean();
    })($codigo, $assist);

    $rendered = html_entity_decode($rendered, ENT_QUOTES | ENT_HTML5);
    $rendered = str_replace('___AMPERSAND___', '&', $rendered);
    $rendered = str_replace(array_keys($escapes), array_values($escapes), $rendered);

    return trim(str_replace(array_values($placeholders), array_keys($placeholders), $rendered))."\n";
}

$blade = new BladeCompiler(new Filesystem, sys_get_temp_dir());
$arquivos = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($origem, FilesystemIterator::SKIP_DOTS));

foreach ($arquivos as $arquivo) {
    $relativo = str_replace('\\', '/', substr($arquivo->getPathname(), strlen($origem) + 1));
    $saida = $destino.'/'.preg_replace('/\.blade\.php$/', '.md', $relativo);
    // SKILL.md vira indice.md: dentro de outra skill, um SKILL.md seria lido como skill própria.
    $saida = preg_replace('#(^|/)SKILL\.md$#', '$1indice.md', $saida);
    @mkdir(dirname($saida), 0777, true);
    $texto = file_get_contents($arquivo->getPathname());

    if (str_ends_with($relativo, '.blade.php')) {
        $texto = renderiza($texto, $blade, $assist);
    }

    file_put_contents($saida, $texto);
}

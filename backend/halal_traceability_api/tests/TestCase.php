<?php

namespace Tests;

use Illuminate\Filesystem\Filesystem;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\Storage;

/**
 * Base test case for feature and unit tests in this project.
 */
abstract class TestCase extends BaseTestCase
{
    protected function fakePublicDisk(): void
    {
        $root = sys_get_temp_dir().DIRECTORY_SEPARATOR.'halaltrack-public-test';

        (new Filesystem())->cleanDirectory($root);

        Storage::set('public', Storage::createLocalDriver([
            'driver' => 'local',
            'root' => $root,
            'url' => 'http://localhost/storage',
            'visibility' => 'public',
            'throw' => false,
        ]));
    }
}

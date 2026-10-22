<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Level extends Model
{
    protected $fillable = ['name', 'markup', 'is_default'];

    protected function casts(): array
    {
        return ['markup' => 'integer', 'is_default' => 'boolean'];
    }

    public static function default(): ?self
    {
        return static::where('is_default', true)->first();
    }
}

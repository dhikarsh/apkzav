<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'phone' => '08'.fake()->unique()->numerify('##########'),
            'pin' => '123456',
            'role' => 'member',
        ];
    }

    public function admin(): static
    {
        return $this->state(fn () => [
            'role' => 'admin',
            'email' => fake()->unique()->safeEmail(),
            'password' => 'password',
        ]);
    }
}

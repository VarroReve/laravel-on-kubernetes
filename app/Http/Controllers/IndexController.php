<?php

namespace App\Http\Controllers;

use App\User;
use Illuminate\Support\Facades\Cache;

class IndexController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Contracts\View\Factory|\Illuminate\View\View
     */
    public function index()
    {
        return view('welcome');
    }
}

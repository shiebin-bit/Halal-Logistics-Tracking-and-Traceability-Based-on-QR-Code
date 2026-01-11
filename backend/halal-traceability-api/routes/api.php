<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// --- 1. Import Controllers ---
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\UserUpdateController;
use App\Http\Controllers\Api\BatchController;
use App\Http\Controllers\Api\LogisticsController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\AdminController;


// --- 2. Public Routes (No Login Required) ---
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::get('/public/batches', [BatchController::class, 'publicIndex']);


// --- 3. Protected Routes (Must have Token) ---
Route::middleware('auth:sanctum')->group(function () {

    // Auth
    Route::post('/logout', [AuthController::class, 'logout']);

    // --- USER PROFILE MANAGEMENT ---
    // Get Profile (Uses UserController)
    Route::get('/user', [UserController::class, 'show']);

    // Update Profile (Uses the new UserUpdateController)
    Route::post('/user/update', [UserUpdateController::class, 'update']);

    // --- BATCH INVENTORY ---
    Route::get('/batches', [BatchController::class, 'index']);
    Route::post('/batches', [BatchController::class, 'store']);
    Route::get('/batches/{id}', [BatchController::class, 'show']);
    Route::post('/batches/update-status', [BatchController::class, 'updateStatus']);

    // --- REPORTS ---
    Route::get('/reports/manifest', [ReportController::class, 'downloadManifest']);
    Route::get('/reports/audit-logs', [ReportController::class, 'getAuditLogs']);

    // --- LOGISTICS ---
    Route::get('/logistics/routes', [LogisticsController::class, 'getAssignedRoutes']);
    Route::post('/logistics/checkpoint', [LogisticsController::class, 'submitCheckpoint']);
    Route::post('/logistics/incident', [LogisticsController::class, 'reportIncident']);

    // Admin Routes
    Route::get('/admin/stats', [AdminController::class, 'getStats']);
    Route::get('/admin/users', [AdminController::class, 'getUsers']);
    Route::post('/admin/approve/{id}', [AdminController::class, 'approveUser']);
});
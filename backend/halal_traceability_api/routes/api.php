<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\UserUpdateController;
use App\Http\Controllers\Api\BatchController;
use App\Http\Controllers\Api\LogisticsController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\RetailerController;


// Public Routes (No Authentication Required)
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
Route::get('/public/batches', [BatchController::class, 'publicIndex']);


// Protected Routes (Requires Sanctum Token)
Route::middleware('auth:sanctum')->group(function () {

    // Authentication
    Route::post('/logout', [AuthController::class, 'logout']);

    // User Profile
    Route::get('/user', [UserController::class, 'show']);
    Route::post('/user/update', [UserUpdateController::class, 'update']);

    // Batch Management
    Route::get('/batches', [BatchController::class, 'index']);
    Route::post('/batches', [BatchController::class, 'store']);
    Route::get('/batches/{id}', [BatchController::class, 'show']);
    Route::post('/batches/update-status', [BatchController::class, 'updateStatus']);

    // Reports
    Route::get('/reports/manifest', [ReportController::class, 'downloadManifest']);
    Route::get('/reports/audit-logs', [ReportController::class, 'getAuditLogs']);

    // Logistics
    Route::get('/logistics/routes', [LogisticsController::class, 'getAssignedRoutes']);
    Route::post('/logistics/checkpoint', [LogisticsController::class, 'submitCheckpoint']);
    Route::post('/logistics/incident', [LogisticsController::class, 'reportIncident']);

    // Admin (role-checked in AdminController constructor)
    Route::get('/admin/stats', [AdminController::class, 'getStats']);
    Route::get('/admin/users', [AdminController::class, 'getUsers']);
    Route::post('/admin/approve/{id}', [AdminController::class, 'approveUser']);
    Route::post('/admin/reject/{id}', [AdminController::class, 'rejectUser']);
    Route::get('/admin/incidents', [AdminController::class, 'getIncidents']);

    // Retailer
    Route::get('/retailer/incoming', [RetailerController::class, 'incoming']);
    Route::get('/retailer/inventory', [RetailerController::class, 'inventory']);
    Route::post('/retailer/accept', [RetailerController::class, 'accept']);
    Route::post('/retailer/reject', [RetailerController::class, 'reject']);
});

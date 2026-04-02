<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reset Password</title>
    <style>
        body {
            margin: 0;
            font-family: Arial, sans-serif;
            background: #f3f4f6;
            color: #111827;
        }

        .page {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
        }

        .card {
            width: 100%;
            max-width: 420px;
            background: #ffffff;
            border-radius: 16px;
            box-shadow: 0 10px 30px rgba(15, 23, 42, 0.1);
            padding: 28px;
        }

        h1 {
            margin: 0 0 8px;
            font-size: 28px;
        }

        p {
            margin: 0 0 20px;
            color: #4b5563;
            line-height: 1.5;
        }

        label {
            display: block;
            margin: 0 0 8px;
            font-size: 14px;
            font-weight: 600;
        }

        input {
            box-sizing: border-box;
            width: 100%;
            padding: 12px 14px;
            margin-bottom: 16px;
            border: 1px solid #d1d5db;
            border-radius: 10px;
            font-size: 14px;
        }

        button {
            width: 100%;
            border: 0;
            border-radius: 10px;
            padding: 12px 16px;
            font-size: 14px;
            font-weight: 700;
            color: #ffffff;
            background: #1565c0;
            cursor: pointer;
        }

        .success {
            margin-bottom: 16px;
            padding: 12px 14px;
            border-radius: 10px;
            background: #dcfce7;
            color: #166534;
        }

        .error {
            margin-bottom: 16px;
            padding: 12px 14px;
            border-radius: 10px;
            background: #fee2e2;
            color: #991b1b;
        }
    </style>
</head>
<body>
    <div class="page">
        <div class="card">
            <h1>Reset Password</h1>
            <p>Set a new password for <strong>{{ $email }}</strong>.</p>

            @if ($status)
                <div class="success">{{ $status }}</div>
            @endif

            @if ($errors->any())
                <div class="error">{{ $errors->first() }}</div>
            @endif

            <form method="POST" action="{{ route('password.update') }}">
                @csrf
                <input type="hidden" name="token" value="{{ $token }}">

                <label for="email">Email</label>
                <input id="email" name="email" type="email" value="{{ old('email', $email) }}" readonly>

                <label for="password">New Password</label>
                <input id="password" name="password" type="password" required minlength="8">

                <label for="password_confirmation">Confirm New Password</label>
                <input id="password_confirmation" name="password_confirmation" type="password" required minlength="8">

                <button type="submit">Update Password</button>
            </form>
        </div>
    </div>
</body>
</html>

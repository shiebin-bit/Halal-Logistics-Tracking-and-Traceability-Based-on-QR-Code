<!DOCTYPE html>
<html>

<head>
    <title>Halal Manifest</title>
    <style>
        body {
            font-family: sans-serif;
        }

        table {
            width: 100%;
            border-collapse: collapse;
        }

        th,
        td {
            border: 1px solid black;
            padding: 8px;
            text-align: left;
        }

        th {
            background-color: #f2f2f2;
        }
    </style>
</head>

<body>
    <h2>Halal Logistics Manifest</h2>
    <p>Date: {{ date('Y-m-d') }}</p>
    <table>
        <thead>
            <tr>
                <th>Batch ID</th>
                <th>Product</th>
                <th>Status</th>
                <th>Origin</th>
            </tr>
        </thead>
        <tbody>
            @foreach($batches as $batch)
                <tr>
                    <td>{{ $batch->batch_id }}</td>
                    <td>{{ $batch->product_type }}</td>
                    <td>{{ $batch->status }}</td>
                    <td>{{ $batch->origin_farm }}</td>
                </tr>
            @endforeach
        </tbody>
    </table>
</body>

</html>
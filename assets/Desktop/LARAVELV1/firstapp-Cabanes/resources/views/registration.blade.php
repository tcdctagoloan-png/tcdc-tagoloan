<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Register Class</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-yellow-100 flex items-center justify-center min-h-screen">
    <div class="bg-white p-6 rounded-lg shadow-lg w-80">
        <h2 class="text-2xl font-bold mb-4">Register Class</h2>
        <form>
            <div class="mb-4">
                <label for="class-id" class="block text-gray-700">Class ID:</label>
                <input type="text" id="class-id" class="w-full px-3 py-2 border border-gray-300 rounded-md">
            </div>
            <div class="mb-4">
                <label for="class-name" class="block text-gray-700">Class Name:</label>
                <input type="text" id="class-name" class="w-full px-3 py-2 border border-gray-300 rounded-md">
            </div>
            <div class="mb-4">
                <label for="class-schedule" class="block text-gray-700">Class Schedule:</label>
                <input type="text" id="class-schedule" class="w-full px-3 py-2 border border-gray-300 rounded-md">
            </div>
            <div class="mb-4">
                <label for="student-id" class="block text-gray-700">Student ID:</label>
                <input type="text" id="student-id" class="w-full px-3 py-2 border border-gray-300 rounded-md">
            </div>
            <button type="submit" class="w-full bg-blue-500 text-white py-2 rounded-md">Save</button>
        </form>
    </div>
</body>
</html>
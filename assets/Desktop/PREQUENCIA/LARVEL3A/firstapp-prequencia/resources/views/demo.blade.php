<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>Document</title>
</head>
<body>
    <form action="submit-demo" method="POST">
        @csrf
        <div>
            <label for="username">Username:</label>
            <input type="text" name="username" id="username">
            @error('username')
            <p class="m-0 small alert-danger shadow sm">{{$message}}</p>
            @enderror
        </div>
        <br>
        <div>
            <label for="email">Email:</label>
            <input type="email" name="email" id="email">
        </div>
        <br>
        <div>
            <label for="password">Password:</label>
            <input type="password" name="password" id="password">
        </div>
        <br>
        <input type="submit" value="Submit">
    </form>
</body>
</html>
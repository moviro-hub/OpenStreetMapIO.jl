using Test
using OpenStreetMapIO

@testset "Utils - url_encode" begin
    @test OpenStreetMapIO.url_encode("a b") == "a%20b"
    @test OpenStreetMapIO.url_encode("[x]") == "%5Bx%5D"
    @test occursin("%0A", OpenStreetMapIO.url_encode("x\ny"))
    @test OpenStreetMapIO.url_encode("a&b=c") == "a%26b%3Dc"
end

@testset "Utils - decode_html_entities" begin
    @test OpenStreetMapIO.decode_html_entities("A &amp; B") == "A & B"
    @test OpenStreetMapIO.decode_html_entities("&lt;tag&gt;") == "<tag>"
    @test OpenStreetMapIO.decode_html_entities("' &apos; &#39;") == "' ' '"
    @test OpenStreetMapIO.decode_html_entities("no entities") == "no entities"
end

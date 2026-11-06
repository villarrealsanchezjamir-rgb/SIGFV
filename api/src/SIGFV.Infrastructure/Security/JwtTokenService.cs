using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using SIGFV.Application.Abstractions;
using SIGFV.Domain;

namespace SIGFV.Infrastructure.Security;

public sealed class JwtTokenService : ITokenService
{
    private readonly string _secret;
    private readonly int _hours;

    public JwtTokenService(string secret, int hours = 8)
    {
        if (string.IsNullOrWhiteSpace(secret) || secret.Length < 32)
            throw new InvalidOperationException("JWT_SECRET debe tener al menos 32 caracteres.");
        _secret = secret;
        _hours = hours;
    }

    public string Create(CurrentSession session, string operador)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, (session.UserId ?? 0).ToString()),
            new("rid", session.RoleId.ToString()),
            new("eid", session.EmpresaId.ToString()),
            new("role", session.RoleName),
            new("empresa", session.EmpresaName),
            new("op", operador)
        };

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            claims: claims,
            notBefore: DateTime.UtcNow,
            expires: DateTime.UtcNow.AddHours(_hours),
            signingCredentials: creds);
        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
